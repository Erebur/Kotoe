//
//  CloudKitRecordResolver.swift
//  Kōtoe
//
//  Created by Simon Weber on 28.10.26.
//

import Foundation
import SQLite3
import SwiftData

/// The transfer that produced a failed record.
enum SyncRecordAction: Equatable {
    case upload
    case download
    case delete
    case setup
    case other
}

/// Maps the `CKRecord` names in a CloudKit partial failure back to the local
/// SwiftData objects they mirror.
///
/// Core Data names a record `CD_<Entity>_<UUID>` and keeps the mapping between
/// that name and the local row in the store's `ANSCKRECORDMETADATA` table.
/// SwiftData exposes no API for that table, and the record accessors on
/// `NSPersistentCloudKitContainer` are hidden from Swift, so the mapping is
/// read from the store directly. Everything here is best effort and
/// read-only: when the table, the object, or the store cannot be read, the
/// caller keeps showing the raw record name.
@MainActor
struct CloudKitRecordResolver {

    // MARK: - Result

    struct Result {
        let action: SyncRecordAction
        /// Core Data entity name, such as `Flashcard`.
        let entity: String?
        /// Human-readable local item, such as `Card "What is 2+2?"`.
        let item: String?
    }

    // MARK: - Store

    private let storeURL: URL?
    private let container: ModelContainer?

    init(container: ModelContainer?) {
        self.container = container
        self.storeURL = container?.configurations.first?.url
    }

    // MARK: - Resolution

    func resolve(
        recordNames: [String],
        operation: CloudKitSyncMonitor.SyncFailure.Operation
    ) -> [Result] {
        guard !recordNames.isEmpty else { return [] }

        let lookups = storeURL.map {
            lookup(recordNames: recordNames, in: $0)
        } ?? [:]

        return recordNames.map { recordName in
            let lookup = lookups[Self.lookupKey(for: recordName)]

            let action: SyncRecordAction

            switch operation {
            case .export:
                action = lookup?.needsDelete == true ? .delete : .upload
            case .import:
                action = .download
            case .setup:
                action = .setup
            case .other:
                action = .other
            }

            return Result(
                action: action,
                entity: lookup?.entity ?? Self.entityName(from: recordName),
                item: lookup.flatMap { item(for: $0) }
            )
        }
    }

    // MARK: - Store Lookup

    private struct Lookup {
        let entity: String
        let id: UUID?
        let needsDelete: Bool
    }

    private struct RecordMetadata {
        let entity: String
        let primaryKey: Int64
        let needsDelete: Bool
    }

    /// Resolves every record of one failure through a single read-only
    /// connection, so a batch that rejected many records does not open the
    /// store once per record.
    private func lookup(
        recordNames: [String],
        in storeURL: URL
    ) -> [String: Lookup] {
        var uuids: [String: String] = [:]

        for recordName in recordNames {
            guard let uuid = Self.uuidText(from: recordName) else { continue }
            uuids[Self.lookupKey(for: recordName)] = uuid
        }

        guard !uuids.isEmpty else { return [:] }

        var database: OpaquePointer?

        guard
            sqlite3_open_v2(
                storeURL.path,
                &database,
                SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
                nil
            ) == SQLITE_OK,
            let database
        else {
            sqlite3_close(database)
            return [:]
        }

        defer { sqlite3_close(database) }

        // CloudKit can report the failure while the store is mid-write. A
        // short wait is enough for the read to see a consistent snapshot; a
        // busy store only costs the resolved label, never the log entry.
        sqlite3_busy_timeout(database, 300)

        var result: [String: Lookup] = [:]

        for (key, uuid) in uuids {
            guard
                let metadata = recordMetadata(for: uuid, database: database)
            else { continue }

            result[key] = Lookup(
                entity: metadata.entity,
                id: objectID(
                    entity: metadata.entity,
                    primaryKey: metadata.primaryKey,
                    database: database
                ),
                needsDelete: metadata.needsDelete
            )
        }

        return result
    }

    private func recordMetadata(
        for recordName: String,
        database: OpaquePointer
    ) -> RecordMetadata? {
        let sql = """
            SELECT ZENTITYID, ZENTITYPK, ZNEEDSCLOUDDELETE
            FROM ANSCKRECORDMETADATA
            WHERE ZCKRECORDNAME = ? COLLATE NOCASE
            LIMIT 1
            """

        var statement: OpaquePointer?

        guard
            sqlite3_prepare_v2(
                database,
                sql,
                -1,
                &statement,
                nil
            ) == SQLITE_OK
        else { return nil }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(
            statement,
            1,
            recordName,
            -1,
            sqliteTransient
        )

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        let entityID = sqlite3_column_int64(statement, 0)
        let primaryKey = sqlite3_column_int64(statement, 1)
        let needsDelete = sqlite3_column_int64(statement, 2) != 0

        guard
            let entity = entityName(id: entityID, database: database)
        else { return nil }

        return RecordMetadata(
            entity: entity,
            primaryKey: primaryKey,
            needsDelete: needsDelete
        )
    }

    private func entityName(
        id: Int64,
        database: OpaquePointer
    ) -> String? {
        var statement: OpaquePointer?

        guard
            sqlite3_prepare_v2(
                database,
                "SELECT Z_NAME FROM Z_PRIMARYKEY WHERE Z_ENT = ?",
                -1,
                &statement,
                nil
            ) == SQLITE_OK
        else { return nil }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, id)

        guard
            sqlite3_step(statement) == SQLITE_ROW,
            let text = sqlite3_column_text(statement, 0)
        else { return nil }

        return String(cString: text)
    }

    /// Entity names are checked against the known schema before being used in
    /// the table name, so a damaged metadata table cannot inject SQL.
    private static let knownEntities: Set<String> = [
        "Subject",
        "FlashcardSet",
        "Flashcard",
        "FlashcardSide",
        "FlashcardReview",
    ]

    private func objectID(
        entity: String,
        primaryKey: Int64,
        database: OpaquePointer
    ) -> UUID? {
        guard Self.knownEntities.contains(entity) else { return nil }

        let table = "Z" + entity.uppercased()
        var statement: OpaquePointer?

        guard
            sqlite3_prepare_v2(
                database,
                "SELECT ZID FROM \(table) WHERE Z_PK = ?",
                -1,
                &statement,
                nil
            ) == SQLITE_OK
        else { return nil }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, primaryKey)

        guard
            sqlite3_step(statement) == SQLITE_ROW,
            let blob = sqlite3_column_blob(statement, 0),
            sqlite3_column_bytes(statement, 0) == 16
        else { return nil }

        var bytes = [UInt8](repeating: 0, count: 16)

        bytes.withUnsafeMutableBytes { destination in
            destination.copyBytes(
                from: UnsafeRawBufferPointer(start: blob, count: 16)
            )
        }

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    // MARK: - Item Lookup

    private func item(for lookup: Lookup) -> String? {
        guard let container, let id = lookup.id else { return nil }

        let context = container.mainContext

        switch lookup.entity {
        case "Subject":
            guard
                let subject = try? context.fetch(
                    FetchDescriptor<Subject>(
                        predicate: #Predicate { $0.id == id }
                    )
                ).first
            else { return nil }

            return Self.subjectLabel(subject)

        case "FlashcardSet":
            guard
                let set = try? context.fetch(
                    FetchDescriptor<FlashcardSet>(
                        predicate: #Predicate { $0.id == id }
                    )
                ).first
            else { return nil }

            return Self.setLabel(set)

        case "Flashcard":
            guard
                let card = try? context.fetch(
                    FetchDescriptor<Flashcard>(
                        predicate: #Predicate { $0.id == id }
                    )
                ).first
            else { return nil }

            return Self.cardLabel(card)

        case "FlashcardSide":
            guard
                let side = try? context.fetch(
                    FetchDescriptor<FlashcardSide>(
                        predicate: #Predicate { $0.id == id }
                    )
                ).first
            else { return nil }

            return Self.sideLabel(side)

        case "FlashcardReview":
            guard
                let review = try? context.fetch(
                    FetchDescriptor<FlashcardReview>(
                        predicate: #Predicate { $0.id == id }
                    )
                ).first
            else { return nil }

            return Self.reviewLabel(review)

        default:
            return nil
        }
    }

    // MARK: - Labels

    private static func subjectLabel(_ subject: Subject) -> String {
        let name = trimmed(subject.name)

        guard !name.isEmpty else {
            return String(localized: "contentView.syncLog.entity.subject")
        }

        return String(
            localized: "contentView.syncLog.item.subject",
            defaultValue: "Subject “\(name)”"
        )
    }

    private static func setLabel(_ set: FlashcardSet) -> String {
        let name = trimmed(set.name)
        let subject = trimmed(set.subject?.name ?? "")

        guard !name.isEmpty else {
            return String(localized: "contentView.syncLog.entity.set")
        }

        guard !subject.isEmpty else {
            return String(
                localized: "contentView.syncLog.item.set",
                defaultValue: "Set “\(name)”"
            )
        }

        return String(
            localized: "contentView.syncLog.item.setInSubject",
            defaultValue: "Set “\(name)” in “\(subject)”"
        )
    }

    private static func cardLabel(_ card: Flashcard) -> String {
        let summary = cardSummary(card)
        let setName = trimmed(card.flashcardSet?.name ?? "")

        guard !summary.isEmpty else {
            return String(localized: "contentView.syncLog.entity.card")
        }

        guard !setName.isEmpty else {
            return String(
                localized: "contentView.syncLog.item.card",
                defaultValue: "Card “\(summary)”"
            )
        }

        return String(
            localized: "contentView.syncLog.item.cardInSet",
            defaultValue: "Card “\(summary)” in “\(setName)”"
        )
    }

    private static func sideLabel(_ side: FlashcardSide) -> String {
        let summary = cardSummary(side.flashcard)

        guard !summary.isEmpty else {
            return String(localized: "contentView.syncLog.entity.side")
        }

        switch side.role {
        case .front:
            return String(
                localized: "contentView.syncLog.item.frontSide",
                defaultValue: "Front of “\(summary)”"
            )

        case .back:
            return String(
                localized: "contentView.syncLog.item.backSide",
                defaultValue: "Back of “\(summary)”"
            )
        }
    }

    private static func reviewLabel(_ review: FlashcardReview) -> String {
        let summary = cardSummary(review.card)

        guard !summary.isEmpty else {
            return String(localized: "contentView.syncLog.item.reviewMark")
        }

        return String(
            localized: "contentView.syncLog.item.review",
            defaultValue: "Review of “\(summary)”"
        )
    }

    private static func cardSummary(_ card: Flashcard?) -> String {
        guard let card else { return "" }
        return snippet(card.front?.summary ?? "")
    }

    private static func snippet(_ text: String) -> String {
        let line = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard line.count > 48 else { return line }
        return String(line.prefix(47)) + "…"
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Record Names

    /// Extracts `Flashcard` from `CD_Flashcard_<UUID>`. A record name without
    /// the prefix (a zone name, for example) has no entity.
    private static func entityName(from recordName: String) -> String? {
        guard recordName.hasPrefix("CD_") else { return nil }

        let parts = recordName.split(separator: "_")
        guard parts.count >= 3 else { return nil }

        return String(parts[1])
    }

    /// The metadata table stores the bare UUID, while a partial error can name
    /// the record `CD_<Entity>_<UUID>`. Take the last component either way.
    private static func uuidText(from recordName: String) -> String? {
        let candidate = recordName
            .split(separator: "_")
            .last
            .map(String.init) ?? recordName

        return UUID(uuidString: candidate) == nil ? nil : candidate
    }

    /// Keys lookups by UUID, so a bare record name and its `CD_` form share
    /// one entry. The metadata query itself is case-insensitive.
    private static func lookupKey(for recordName: String) -> String {
        (uuidText(from: recordName) ?? recordName).lowercased()
    }
}

/// SQLite copies the bound string before the statement runs, so the Swift
/// string does not have to outlive the call.
private let sqliteTransient = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)
