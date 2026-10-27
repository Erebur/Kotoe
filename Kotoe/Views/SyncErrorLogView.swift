//
//  SyncErrorLogView.swift
//  Kōtoe
//
//  Created by Simon Weber on 27.10.26.
//

import SwiftUI

/// Every distinct failure the CloudKit mirror reported since launch, behind
/// the sync line in the library footer.
///
/// The library footer can only say that something failed; this sheet keeps the
/// actual error, its domain and code, and CloudKit's underlying or partial
/// errors, so a TestFlight report can be backed by details.
struct SyncErrorLogView: View {

    @Environment(\.dismiss) private var dismiss

    let monitor: CloudKitSyncMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .logSheetSize()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(
                symbol: "exclamationmark.icloud.fill",
                tint: KotoeTheme.accent,
                size: 44
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("contentView.syncLog.title")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Text("contentView.syncLog.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if monitor.failures.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(monitor.failures) { failure in
                        failureRow(failure)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.automatic)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(KotoeTheme.success)

            Text("contentView.syncLog.empty.title")
                .font(.headline)

            Text("contentView.syncLog.empty.message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func failureRow(
        _ failure: CloudKitSyncMonitor.SyncFailure
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(failure.operation.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KotoeTheme.accent)

                if failure.count > 1 {
                    Text(verbatim: "×\(failure.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(KotoeTheme.fieldBackground)
                        )
                }

                Spacer(minLength: 8)

                Text(
                    failure.lastSeenAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            Text(verbatim: failure.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let technical = failure.technicalSummary {
                Text(verbatim: technical)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !failure.details.isEmpty {
                detailsSection(failure.details)
            }

            if !failure.recordErrors.isEmpty {
                recordErrorsSection(failure.recordErrors)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(KotoeTheme.fieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(KotoeTheme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// The errors nested inside the reported one. For `CKErrorDomain` 2 this
    /// is where the actual reason lives, so the section is never hidden.
    private func detailsSection(
        _ details: [CloudKitSyncMonitor.SyncFailure.Detail]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "contentView.syncLog.details.title",
                systemImage: "list.bullet.indent"
            )

            ForEach(details) { detail in
                VStack(alignment: .leading, spacing: 2) {
                    detailLabel(detail.kind.title, count: detail.count)

                    Text(verbatim: detail.technicalLine)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 2)
    }

    /// One row per record CloudKit rejected in a partial failure, with that
    /// record's own error underneath it.
    private func recordErrorsSection(
        _ records: [CloudKitSyncMonitor.SyncFailure.RecordError]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "contentView.syncLog.records.title",
                systemImage: "doc.on.doc"
            )

            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(verbatim: record.record)
                            .font(
                                .system(.caption2, design: .monospaced)
                                    .weight(.semibold)
                            )
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        if record.count > 1 {
                            Text(verbatim: "×\(record.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(verbatim: record.technicalLine)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 2)
    }

    private func detailLabel(
        _ title: LocalizedStringKey,
        count: Int
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if count > 1 {
                Text(verbatim: "×\(count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button("contentView.syncLog.clear") {
                monitor.clearFailures()
            }
            .disabled(monitor.failures.isEmpty)

            Spacer()

            Button("shared.actions.done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(KotoeTheme.accent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Detail Titles

private extension CloudKitSyncMonitor.SyncFailure.Detail.Kind {

    var title: LocalizedStringKey {
        switch self {
        case .underlying: return "contentView.syncLog.details.underlying"
        case .debugDescription: return "contentView.syncLog.details.debug"
        case .failureReason: return "contentView.syncLog.details.reason"
        case .recoverySuggestion:
            return "contentView.syncLog.details.suggestion"
        case .retryAfter: return "contentView.syncLog.details.retryAfter"
        }
    }
}

// MARK: - Operation Titles

private extension CloudKitSyncMonitor.SyncFailure.Operation {

    var title: LocalizedStringKey {
        switch self {
        case .setup: return "contentView.syncLog.operation.setup"
        case .import: return "contentView.syncLog.operation.import"
        case .export: return "contentView.syncLog.operation.export"
        case .other: return "contentView.syncLog.operation.other"
        }
    }
}

// MARK: - Previews

#Preview {
    SyncErrorLogView(
        monitor: CloudKitSyncMonitor(
            failures: [
                CloudKitSyncMonitor.SyncFailure(
                    operation: .export,
                    message:
                        "The operation couldn't be completed. "
                        + "(CKErrorDomain error 2.)",
                    domain: "CKErrorDomain",
                    code: 2,
                    details: [
                        .init(
                            kind: .underlying,
                            domain: "NSCocoaErrorDomain",
                            code: 134060,
                            message: "A Core Data error occurred.",
                            count: 1
                        ),
                        .init(
                            kind: .debugDescription,
                            domain: nil,
                            code: nil,
                            message:
                                "CoreData+CloudKit: Failed to export: "
                                + "Couldn't send a batch of records.",
                            count: 1
                        ),
                        .init(
                            kind: .retryAfter,
                            domain: nil,
                            code: nil,
                            message: "30 s",
                            count: 1
                        ),
                    ],
                    recordErrors: [
                        .init(
                            record: "CD_Flashcard_2F8C4A1E",
                            domain: "CKErrorDomain",
                            code: 12,
                            message:
                                "Invalid arguments. Cannot create field "
                                + "'checksCapitalization' in record type "
                                + "'CD_FlashcardSet'.",
                            count: 1
                        ),
                        .init(
                            record: "CD_FlashcardSide_91AB77D0",
                            domain: "CKErrorDomain",
                            code: 12,
                            message:
                                "Invalid arguments. Cannot create field "
                                + "'mediaFileName' in record type "
                                + "'CD_FlashcardSide'.",
                            count: 2
                        ),
                    ],
                    lastSeenAt: .now,
                    count: 3
                ),
                CloudKitSyncMonitor.SyncFailure(
                    operation: .import,
                    message:
                        "The operation couldn't be completed. "
                        + "(CKErrorDomain error 9.)",
                    domain: "CKErrorDomain",
                    code: 9,
                    details: [],
                    recordErrors: [],
                    lastSeenAt: .now.addingTimeInterval(-900),
                    count: 1
                ),
            ]
        )
    )
}
