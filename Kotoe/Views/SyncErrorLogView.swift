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
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(
                        Array(failure.details.enumerated()),
                        id: \.offset
                    ) { _, line in
                        Text(verbatim: line)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
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
                        "  NSDebugDescription: Error Domain=CKErrorDomain "
                            + "Code=2 \"An internal server error occurred.\"",
                        "  CKErrorRetryAfterKey: 30",
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
                    lastSeenAt: .now.addingTimeInterval(-900),
                    count: 1
                ),
            ]
        )
    )
}
