//
//  CloudKitSyncMonitor.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import CoreData
import Foundation
import Observation

/// Watches the CloudKit mirror that SwiftData runs underneath the app.
///
/// A failed import or export never reaches the interface on its own: the
/// mirror keeps retrying in the background while the local store continues to
/// work, so the app silently shows stale data. This monitor turns those
/// events into state the interface can display and logs them for debugging.
@MainActor
@Observable
final class CloudKitSyncMonitor {

    // MARK: - State

    enum State: Equatable {
        /// The mirror has not reported anything yet.
        case idle
        /// A setup, import, or export is running.
        case syncing
        /// The last finished operation succeeded.
        case synced(Date)
        /// The last finished operation failed.
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastImportedAt: Date?
    private(set) var lastExportedAt: Date?
    private(set) var lastErrorDescription: String?

    // MARK: - Observation

    /// The app owns the only instance, so the token is kept for the lifetime
    /// of the process rather than removed in `deinit`.
    @ObservationIgnored private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer
                        .eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event
            else {
                return
            }

            // The observer is registered on the main queue.
            MainActor.assumeIsolated {
                self?.apply(event)
            }
        }
    }

    // MARK: - Events

    private func apply(_ event: NSPersistentCloudKitContainer.Event) {
        // The mirror posts twice per operation: once when it starts and once
        // when it finishes.
        guard let endDate = event.endDate else {
            state = .syncing
            return
        }

        guard event.succeeded else {
            let message = event.error?.localizedDescription
                ?? "Unknown CloudKit error"

            lastErrorDescription = message
            state = .failed(message)

            print("[CloudKit] \(event.type.logName) failed: \(message)")
            return
        }

        switch event.type {
        case .import:
            lastImportedAt = endDate
            lastErrorDescription = nil
            state = .synced(endDate)
            print("[CloudKit] import finished at \(endDate)")

        case .export:
            lastExportedAt = endDate
            lastErrorDescription = nil
            state = .synced(endDate)
            print("[CloudKit] export finished at \(endDate)")

        case .setup:
            // Setup succeeding only means sync is available, not that any
            // data moved, so it leaves the reported state alone.
            break

        @unknown default:
            break
        }
    }
}

// MARK: - Event Type Logging

private extension NSPersistentCloudKitContainer.EventType {

    var logName: String {
        switch self {
        case .setup: return "setup"
        case .import: return "import"
        case .export: return "export"
        @unknown default: return "event"
        }
    }
}
