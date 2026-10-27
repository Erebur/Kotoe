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

        /// An error nested inside the one the mirror reported: an underlying
        /// error, CloudKit's debug text, a failure reason, or a retry hint.
        struct Detail: Identifiable, Equatable {

            enum Kind: Equatable {
                case underlying
                case debugDescription
                case failureReason
                case recoverySuggestion
                case retryAfter
            }

            let id = UUID()
            let kind: Kind
            let domain: String?
            let code: Int?
            let message: String
            var count: Int

            /// "CKErrorDomain 12: Invalid arguments", or the bare message when
            /// the detail is plain text rather than an error of its own.
            var technicalLine: String {
                formattedErrorLine(
                    domain: domain,
                    code: code,
                    message: message
                )
            }
        }

        /// One record CloudKit rejected inside a partial failure
        /// (`CKErrorDomain` 2). Without these rows the outer error only says
        /// that some records of a batch failed.
        struct RecordError: Identifiable, Equatable {

            let id = UUID()
            let record: String
            let domain: String?
            let code: Int?
            let message: String
            var count: Int

            var technicalLine: String {
                formattedErrorLine(
                    domain: domain,
                    code: code,
                    message: message
                )
            }
        }

        let id = UUID()
        let operation: Operation
        let message: String
        let domain: String?
        let code: Int?
        let details: [Detail]
        let recordErrors: [RecordError]
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

            for detail in failure.details {
                print(
                    "[CloudKit] \(detail.kind.logName): "
                        + detail.technicalLine
                )
            }

            for record in failure.recordErrors {
                print(
                    "[CloudKit] record \(record.record): "
                        + record.technicalLine
                )
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

        var details: [SyncFailure.Detail] = []
        var recordErrors: [SyncFailure.RecordError] = []

        if let nsError {
            collect(
                nsError,
                depth: 0,
                details: &details,
                recordErrors: &recordErrors
            )
        }

        return SyncFailure(
            operation: operation(for: type),
            message: message,
            domain: nsError?.domain,
            code: nsError?.code,
            details: details,
            recordErrors: recordErrors,
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

    /// Walks everything CloudKit and Core Data attach to an error: underlying
    /// errors, Core Data's detailed errors, the per-record errors of a partial
    /// failure, the debug description, and the retry hint.
    ///
    /// `depth` bounds the walk because an error chain can be several layers
    /// deep; identical entries are grouped so a batch that rejects the same
    /// record repeatedly cannot flood the log.
    private static func collect(
        _ error: NSError,
        depth: Int,
        details: inout [SyncFailure.Detail],
        recordErrors: inout [SyncFailure.RecordError]
    ) {
        guard depth < 6 else { return }

        if depth > 0 {
            append(
                .underlying,
                domain: error.domain,
                code: error.code,
                message: error.localizedDescription,
                to: &details
            )
        }

        if let debug = error.userInfo[NSDebugDescriptionErrorKey] as? String {
            append(
                .debugDescription,
                domain: nil,
                code: nil,
                message: debug,
                to: &details
            )
        }

        if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey]
            as? String
        {
            append(
                .failureReason,
                domain: nil,
                code: nil,
                message: reason,
                to: &details
            )
        }

        if let suggestion = error.userInfo[
            NSLocalizedRecoverySuggestionErrorKey
        ] as? String {
            append(
                .recoverySuggestion,
                domain: nil,
                code: nil,
                message: suggestion,
                to: &details
            )
        }

        if let retryAfter = error.userInfo[CKErrorRetryAfterKey] as? NSNumber {
            append(
                .retryAfter,
                domain: nil,
                code: nil,
                message: "\(Int(retryAfter.doubleValue.rounded())) s",
                to: &details
            )
        }

        // A partial failure (`CKErrorDomain` 2) only says that some records of
        // a batch were rejected. The reason lives here, one error per record.
        if let partial = error.userInfo[CKPartialErrorsByItemIDKey]
            as? [AnyHashable: Any]
        {
            let sorted = partial.sorted {
                recordName(for: $0.key) < recordName(for: $1.key)
            }

            for (itemID, value) in sorted {
                guard let itemError = value as? NSError else { continue }

                appendRecordError(
                    itemID: itemID,
                    error: itemError,
                    to: &recordErrors
                )
            }
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            collect(
                underlying,
                depth: depth + 1,
                details: &details,
                recordErrors: &recordErrors
            )
        }

        if let many = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
            for inner in many {
                collect(
                    inner,
                    depth: depth + 1,
                    details: &details,
                    recordErrors: &recordErrors
                )
            }
        }
    }

    private static func append(
        _ kind: SyncFailure.Detail.Kind,
        domain: String?,
        code: Int?,
        message: String,
        to details: inout [SyncFailure.Detail]
    ) {
        if let index = details.firstIndex(where: {
            $0.kind == kind
                && $0.domain == domain
                && $0.code == code
                && $0.message == message
        }) {
            details[index].count += 1
            return
        }

        details.append(
            SyncFailure.Detail(
                kind: kind,
                domain: domain,
                code: code,
                message: message,
                count: 1
            )
        )
    }

    private static func appendRecordError(
        itemID: AnyHashable,
        error: NSError,
        to recordErrors: inout [SyncFailure.RecordError]
    ) {
        let record = recordName(for: itemID)
        let message = error.localizedDescription

        if let index = recordErrors.firstIndex(where: {
            $0.record == record
                && $0.domain == error.domain
                && $0.code == error.code
                && $0.message == message
        }) {
            recordErrors[index].count += 1
            return
        }

        recordErrors.append(
            SyncFailure.RecordError(
                record: record,
                domain: error.domain,
                code: error.code,
                message: message,
                count: 1
            )
        )
    }

    /// Core Data names its CloudKit records `CD_<Entity>_<UUID>`. Keeping the
    /// raw name lets a failing record be matched in the CloudKit Console.
    private static func recordName(for itemID: AnyHashable) -> String {
        if let id = itemID.base as? CKRecord.ID {
            return id.recordName
        }

        if let zone = itemID.base as? CKRecordZone.ID {
            return zone.zoneName
        }

        return String(describing: itemID.base)
    }
}

/// "CKErrorDomain 12: Invalid arguments", or the bare message when the error
/// carries no domain or code.
private func formattedErrorLine(
    domain: String?,
    code: Int?,
    message: String
) -> String {
    guard let domain, let code else { return message }
    return "\(domain) \(code): \(message)"
}

// MARK: - Detail Logging

private extension CloudKitSyncMonitor.SyncFailure.Detail.Kind {

    var logName: String {
        switch self {
        case .underlying: return "underlying"
        case .debugDescription: return "debug"
        case .failureReason: return "reason"
        case .recoverySuggestion: return "suggestion"
        case .retryAfter: return "retry after"
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
