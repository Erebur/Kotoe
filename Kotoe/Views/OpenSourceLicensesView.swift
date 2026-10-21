//
//  OpenSourceLicensesView.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import SwiftUI

/// Shows the open source license Kōtoe is distributed under.
///
/// The text is read from the `LICENSE` file that ships inside the app
/// bundle, so the in-app copy is always the same as the one in the
/// repository.
struct OpenSourceLicensesView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        summary
                        licenseText
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("licensesView.navigation.title")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("shared.actions.done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .editorSheetSize(width: 640, height: 700)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(
                symbol: "checkmark.seal.fill",
                tint: KotoeTheme.accent,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("licensesView.header.title")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("licensesView.header.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailRow(
                title: "licensesView.detail.license",
                value: Self.license?.name ?? ""
            )

            detailRow(
                title: "licensesView.detail.copyright",
                value: Self.license?.copyright ?? ""
            )

            detailRow(
                title: "licensesView.detail.version",
                value: versionText
            )

            if let repositoryURL = Self.repositoryURL {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("licensesView.detail.sourceCode")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 150, alignment: .leading)

                    Link(destination: repositoryURL) {
                        Text(verbatim: repositoryURL.absoluteString)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .cardSurface(padding: 16, tint: KotoeTheme.accent)
    }

    private func detailRow(
        title: LocalizedStringKey,
        value: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(verbatim: value)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""

        return String(
            localized: "licensesView.version",
            defaultValue: "Version \(short) (\(build))"
        )
    }

    // MARK: - License text

    @ViewBuilder
    private var licenseText: some View {
        if let license = Self.license {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "licensesView.section.licenseText",
                    systemImage: "doc.text"
                )

                Text(verbatim: license.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cardSurface(padding: 16)
        } else {
            Label(
                "licensesView.text.unavailable",
                systemImage: "doc.questionmark"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bundled license

    private struct License {
        let name: String
        let copyright: String
        let text: String
    }

    /// The `LICENSE` file from the app bundle, parsed into the parts the
    /// summary shows and the full text.
    private static let license: License? = {
        guard let url = Bundle.main.url(
            forResource: "LICENSE",
            withExtension: nil
        ), let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return License(
            name: lines.first ?? "",
            copyright: lines.first { $0.hasPrefix("Copyright") } ?? "",
            text: text
        )
    }()

    private static let repositoryURL = URL(
        string: "https://github.com/Erebur/Kotoe"
    )
}
