//
//  PopupView.swift
//  Kōtoe
//
//  Created by Simon Weber on 27.10.26.
//

import SwiftUI

/// A modal sheet with the app's default appearance: an icon header, a
/// content area and a footer with dismissive and primary actions.
///
/// Every popup uses this view so header padding, typography, footer button
/// placement, keyboard shortcuts and platform sizing stay identical
/// instead of being re-implemented by each sheet:
///
/// ```swift
/// .sheet(isPresented: $showing) {
///     PopupView(
///         title: "settings.title",
///         subtitle: "settings.subtitle",
///         systemImage: "gear",
///         primaryAction: { dismiss() }
///     ) {
///         SettingsContent()
///     }
/// }
/// ```
struct PopupView<Content: View>: View {

    /// Title shown in the header.
    let title: LocalizedStringKey

    /// Optional subtitle shown below the title.
    var subtitle: LocalizedStringKey? = nil

    /// Optional SF Symbol shown next to the title in the header. When nil,
    /// the header has no icon.
    var systemImage: String? = nil

    /// Tint of the header icon and the primary button.
    var tint: Color = KotoeTheme.accent

    /// Title of the primary (right) footer button.
    var primaryTitle: LocalizedStringKey = "shared.actions.done"

    /// Action performed when the primary button is tapped. The popup is not
    /// dismissed automatically — the action should dismiss when appropriate.
    var primaryAction: () -> Void = { }

    /// Whether the primary button is disabled.
    var primaryDisabled: Bool = false

    /// Title of the dismissive (left) footer button. Pass `nil` to omit it.
    var cancelTitle: LocalizedStringKey? = "shared.actions.cancel"

    /// Action performed when the cancel button is tapped. Defaults to
    /// dismissing the popup.
    var cancelAction: (() -> Void)? = nil

    /// Clears the initial responder on macOS so the popup opens in a calm,
    /// read-only state. Turn this off for popups that want to pre-focus a
    /// field, such as the create subject/set sheet.
    var clearsInitialFocusOnMac: Bool = true

    /// Horizontal padding applied to the header, content, and footer so every
    /// popup uses the same side margins. Content passed to `content` should
    /// not add its own horizontal padding.
    var contentPadding: CGFloat = 20

    /// Custom footer content, replacing the default cancel/primary buttons.
    var customFooter: AnyView? = nil

    /// The popup's content.
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, contentPadding)

            content
                .padding(.horizontal, contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)

            footerRegion
                .padding(.horizontal, contentPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .popupSize()
        .if(clearsInitialFocusOnMac) { $0.clearInitialFocusOnMac() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            if let systemImage {
                IconTile(symbol: systemImage, tint: tint, size: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerRegion: some View {
        if let customFooter {
            customFooter
        } else {
            defaultFooter
        }
    }

    private var defaultFooter: some View {
        HStack(spacing: 12) {
            if let cancelTitle {
                Button(cancelTitle, role: .cancel) {
                    if let cancelAction {
                        cancelAction()
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.cancelAction)
            }

            Spacer()

            Button(primaryTitle) {
                primaryAction()
            }
            .buttonStyle(.borderedProminent)
            .disabled(primaryDisabled)
            .tint(tint)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Previews

#Preview {
    PopupView(
        title: "Import cards",
        subtitle: "Paste text or import a file to add several cards at once.",
        systemImage: "square.and.arrow.down.on.square"
    ) {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "Paste one card per line, with the term and answer "
                + "separated by a tab, dash or colon.")
            Text(verbatim: "The preview shows exactly what will be created before "
                + "anything is imported.")
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    .frame(width: 520, height: 560)
}
