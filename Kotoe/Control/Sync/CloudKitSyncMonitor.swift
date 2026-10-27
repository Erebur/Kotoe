//
//  CloudKitSyncMonitor.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import CloudKit
import CoreData
import Foundation
import Observation

/// Watches the CloudKit mirror that SwiftData runs underneath the app.
///
/// A failed import or export never reaches the interface on its own: the
/// mirror keeps retrying in the background while the local store continues to
/// work, so the app silently shows stale data. This monitor turns those
/// events into state the interface can display, keeps a log of every distinct
/// failure, and logs them for debugging.
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

    // MARK: - Failures

    /// One failure reported by the CloudKit mirror, kept for the error log
    /// behind the sync line in the library footer.
    struct SyncFailure: Identifiable, Equatable {

        enum Operation {
            case setup
            case `import`
            case export
            case other
        }

        let id = UUID()
        let operation: Operation
        let message: String
        let domain: String?
        let code: Int?
        let details: [String]
        var lastSeenAt: Date
        var count: Int

        /// "CKErrorDomain 2", or nil when CloudKit reported no NSError.
        var technicalSummary: String? {
            guard let domain, let code else { return nil }
            return "\(domain) \(code)"
        }

        /// Repeated failures of the same operation and error are grouped so
        /// the log cannot be flooded by CloudKit's retry loop.
        func matches(_ other: SyncFailure) -> Bool {
            operation == other.operation
                && message == other.message
                && domain == other.domain
                && code == other.code
        }
    }

    /// Caps the in-memory log so a persistent failure cannot grow forever.
    private static let maximumFailures = 100

    private(set) var state: State = .idle
    private(set) var lastImportedAt: Date?
    private(set) var lastExportedAt: Date?
    private(set) var lastErrorDescription: String?

    /// Distinct failures from this session, newest first. Passing a list makes
    /// the monitor usable in previews.
    private(set) var failures: [SyncFailure] = []

    // MARK: - Observation

    /// The app owns the only instance, so the token is kept for the lifetime
    /// of the process rather than removed in `deinit`.
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(failures: [SyncFailure] = []) {
        self.failures = failures

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
            let failure = Self.failure(
                for: event.type,
                error: event.error,
                at: endDate
            )

            record(failure)
            lastErrorDescription = failure.message
            state = .failed(failure.message)

            print("[CloudKit] \(event.type.logName) failed: \(failure.message)")

            if let technical = failure.technicalSummary {
                print("[CloudKit] \(technical)")
            }

            for line in failure.details {
                print("[CloudKit] \(line.trimmingCharacters(in: .whitespaces))")
            }

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

    // MARK: - Failure Log

    /// Empties the log without changing the current sync state.
    func clearFailures() {
        failures.removeAll()
    }

    private func record(_ failure: SyncFailure) {
        if var latest = failures.first, latest.matches(failure) {
            latest.lastSeenAt = failure.lastSeenAt
            latest.count += 1
            failures[0] = latest
            return
        }

        failures.insert(failure, at: 0)

        if failures.count > Self.maximumFailures {
            failures.removeLast(failures.count - Self.maximumFailures)
        }
    }

    private static func failure(
        for type: NSPersistentCloudKitContainer.EventType,
        error: Error?,
        at date: Date
    ) -> SyncFailure {
        let nsError = error as NSError?
        let message = nsError?.localizedDescription
            ?? String(localized: "contentView.footer.sync.failed")

        return SyncFailure(
            operation: operation(for: type),
            message: message,
            domain: nsError?.domain,
            code: nsError?.code,
            details: detailLines(for: nsError),
            lastSeenAt: date,
            count: 1
        )
    }

    private static func operation(
        for type: NSPersistentCloudKitContainer.EventType
    ) -> SyncFailure.Operation {
        switch type {
        case .setup: return .setup
        case .import: return .import
        case .export: return .export
        @unknown default: return .other
        }
    }

    /// Turns an NSError into the extra lines shown under its message:
    /// underlying errors, CloudKit's partial errors per record, and a retry
    /// hint if the server sent one.
    private static func detailLines(
        for error: NSError?,
        depth: Int = 0
    ) -> [String] {
        guard let error, depth < 4 else { return [] }

        let indent = String(repeating: "  ", count: depth)
        var lines: [String] = []

        if depth > 0 {
            lines.append(
                "\(indent)\(error.domain) \(error.code): "
                    + error.localizedDescription
            )
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            lines.append(
                contentsOf: detailLines(for: underlying, depth: depth + 1)
            )
        }

        if let debug = error.userInfo[NSDebugDescriptionErrorKey] as? String {
            lines.append("\(indent)\(debug)")
        }

        if let partial = error.userInfo[CKPartialErrorsByItemIDKey]
            as? [AnyHashable: Error]
        {
            let sorted = partial.sorted {
                String(describing: $0.key) < String(describing: $1.key)
            }

            for (itemID, itemError) in sorted {
                let nsItemError = itemError as NSError
                lines.append(
                    "\(indent)  \(String(describing: itemID)): "
                        + "\(nsItemError.domain) \(nsItemError.code): "
                        + nsItemError.localizedDescription
                )
            }
        }

        if let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? NSNumber {
            lines.append(
                "\(indent)retry after: \(retryAfter.doubleValue) s"
            )
        }

        if lines.count > 20 {
            return Array(lines.prefix(20)) + ["…"]
        }

        return lines
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
