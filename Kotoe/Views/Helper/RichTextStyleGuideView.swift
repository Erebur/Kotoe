//
//  RichTextStyleGuideView.swift
//  Kōtoe
//
//  Created by Simon Weber on 26.10.26.
//
//  The sheet behind the info button in every rich text field. It shows a
//  sample containing every supported markdown and LaTeX convention in a split
//  field: the source on one side, the rendered result on the other.
//

import SwiftUI

struct RichTextStyleGuideView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PopupView(
            title: "shared.richText.styleGuide.title",
            subtitle: "shared.richText.styleGuide.subtitle",
            primaryAction: { dismiss() },
            cancelTitle: nil
        ) {
            RichTextField(
                placeholder: "shared.content.empty",
                attributedText: .constant(sample),
                tint: KotoeTheme.accent,
                showsStyleControls: false,
                displayMode: .constant(.split),
                isEditable: false,
                fillsHeight: true
            )
            .frame(maxHeight: .infinity)
        }
        .popupSize(width: 640, height: 580)
    }

    private var sample: NSAttributedString {
        NSAttributedString(
            string: String(
                localized: "shared.richText.styleGuide.sample",
                defaultValue: """
                # Heading

                Use **bold**, *italic*, ~~strikethrough~~, `code`, and \
                [a link](https://example.com).

                * First bullet
                * Second bullet

                1. First step
                2. Second step

                - [x] Finished task
                - [ ] Open task

                > A quote

                ---

                ```swift
                let answer = 42
                ```

                Inline math $E = mc^2$ and a formula:

                $$\\int_0^1 x^2\\,dx = \\frac{1}{3}$$
                """
            )
        )
    }
}

// MARK: - Preview

#Preview("Style Guide") {
    RichTextStyleGuideView()
}
