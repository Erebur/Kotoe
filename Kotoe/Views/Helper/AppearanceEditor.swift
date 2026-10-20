//
//  AppearanceEditor.swift
//  Kōtoe
//
//  Lets a subject or set choose the SF Symbol and accent color that
//  represent it. Changes are written back to the model by the caller.
//

import SwiftUI

struct AppearanceEditor: View {

    let title: String
    let subtitle: String
    let symbols: [String]

    @Binding var iconName: String?
    @Binding var tintIndex: Int?

    @Environment(\.dismiss) private var dismiss

    @State private var draftSymbol: String
    @State private var draftTintIndex: Int

    init(
        title: String,
        subtitle: String,
        symbols: [String],
        defaultSymbol: String,
        defaultTintIndex: Int,
        iconName: Binding<String?>,
        tintIndex: Binding<Int?>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbols = symbols

        _iconName = iconName
        _tintIndex = tintIndex

        _draftSymbol = State(
            initialValue: iconName.wrappedValue ?? defaultSymbol
        )
        _draftTintIndex = State(
            initialValue: tintIndex.wrappedValue ?? defaultTintIndex
        )
    }

    private var tint: Color {
        KotoeTheme.paletteColor(at: draftTintIndex)
            ?? KotoeTheme.palette[0]
    }

    private var symbolColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 46, maximum: 54), spacing: 10)]
    }

    private var colorColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 34, maximum: 42), spacing: 10)]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    iconSection
                    colorSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            footer
        }
        .clearInitialFocusOnMac()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            IconTile(symbol: draftSymbol, tint: tint, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Icon

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Icon", systemImage: "square.grid.2x2")

            LazyVGrid(columns: symbolColumns, spacing: 10) {
                ForEach(symbols, id: \.self) { symbol in
                    symbolButton(symbol)
                }
            }
        }
    }

    private func symbolButton(_ symbol: String) -> some View {
        let isSelected = symbol == draftSymbol

        return Button {
            draftSymbol = symbol
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(isSelected ? tint : Color.primary.opacity(0.72))
                .frame(width: 46, height: 46)
                .background(
                    isSelected
                        ? tint.opacity(0.16)
                        : KotoeTheme.fieldBackground,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? tint.opacity(0.55)
                                : KotoeTheme.hairline,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(symbol)
        .accessibilityLabel(symbol)
        .if(isSelected) { view in
            view.accessibilityAddTraits(.isSelected)
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Color", systemImage: "paintpalette")

            LazyVGrid(columns: colorColumns, spacing: 10) {
                ForEach(
                    Array(KotoeTheme.palette.enumerated()),
                    id: \.offset
                ) { index, color in
                    colorButton(color, index: index)
                }
            }
        }
    }

    private func colorButton(_ color: Color, index: Int) -> some View {
        let isSelected = index == draftTintIndex

        return Button {
            draftTintIndex = index
        } label: {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(
                            .white.opacity(isSelected ? 0.9 : 0.18),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? color.opacity(0.55) : .clear,
                            lineWidth: 1
                        )
                        .padding(-4)
                )
                .frame(width: 42, height: 42)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Color \(index + 1)")
        .accessibilityLabel("Color \(index + 1)")
        .if(isSelected) { view in
            view.accessibilityAddTraits(.isSelected)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Reset") {
                reset()
            }
            .help("Use the icon and color suggested by the name")

            Spacer()

            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Done") {
                apply()
            }
            .buttonStyle(.borderedProminent)
            .tint(KotoeTheme.accent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
    }

    // MARK: - Actions

    private func apply() {
        iconName = draftSymbol
        tintIndex = draftTintIndex
        dismiss()
    }

    private func reset() {
        iconName = nil
        tintIndex = nil
        dismiss()
    }
}

#Preview {
    AppearanceEditor(
        title: "Subject Appearance",
        subtitle: "Pick an icon and color for this subject.",
        symbols: KotoeTheme.subjectSymbols,
        defaultSymbol: "book.closed.fill",
        defaultTintIndex: 0,
        iconName: .constant(nil),
        tintIndex: .constant(nil)
    )
    .frame(width: 460, height: 560)
}
