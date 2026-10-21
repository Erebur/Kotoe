//
//  Theme.swift
//  Kōtoe
//
//  Shared visual language for the app: brand colors, card surfaces,
//  icon tiles and the small motion helpers used across the UI.
//

import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// MARK: - Brand

enum KotoeTheme {

    /// Terracotta accent taken from the app icon.
    static let accent = Color(red: 0.851, green: 0.408, blue: 0.290)

    /// Warm gold used as a secondary accent.
    static let gold = Color(red: 0.910, green: 0.714, blue: 0.357)

    /// Deep ink green from the app icon.
    static let ink = Color(red: 0.149, green: 0.247, blue: 0.220)

    /// Cream paper from the app icon.
    static let paper = Color(red: 0.969, green: 0.941, blue: 0.898)

    /// Green used for a correct answer.
    static let success = Color(red: 0.235, green: 0.522, blue: 0.404)

    /// Accent palette used to give subjects a stable, recognizable color.
    static let palette: [Color] = [
        Color(red: 0.851, green: 0.408, blue: 0.290),  // terracotta
        Color(red: 0.878, green: 0.631, blue: 0.263),  // gold
        Color(red: 0.294, green: 0.475, blue: 0.396),  // forest
        Color(red: 0.302, green: 0.502, blue: 0.529),  // teal
        Color(red: 0.475, green: 0.341, blue: 0.529),  // plum
        Color(red: 0.561, green: 0.412, blue: 0.490),  // mauve
        Color(red: 0.435, green: 0.514, blue: 0.310),  // olive
        Color(red: 0.678, green: 0.333, blue: 0.239),  // rust
        Color(red: 0.345, green: 0.396, blue: 0.502),  // slate
    ]

    /// Resolves a stored palette index, ignoring out-of-range values.
    static func paletteColor(at index: Int?) -> Color? {
        guard let index, palette.indices.contains(index) else { return nil }
        return palette[index]
    }

    /// Symbols that can represent a subject.
    static let subjectSymbols = [
        "book.closed.fill",
        "graduationcap.fill",
        "function",
        "atom",
        "globe.europe.africa.fill",
        "music.note",
        "paintpalette.fill",
        "brain.head.profile",
        "text.book.closed.fill",
        "chevron.left.forwardslash.chevron.right",
        "leaf.fill",
        "scalemass.fill",
        "clock.arrow.circlepath",
        "cross.case.fill",
        "chart.line.uptrend.xyaxis",
        "flask.fill",
        "theatermasks.fill",
        "camera.fill",
        "film.fill",
        "sportscourt.fill",
        "airplane",
        "hammer.fill",
        "lightbulb.fill",
        "questionmark.circle.fill",
    ]

    /// Symbols that can represent a flashcard set.
    static let setSymbols = [
        "rectangle.stack.fill",
        "square.stack.3d.up.fill",
        "rectangle.on.rectangle.angled",
        "list.bullet.rectangle.fill",
        "folder.fill",
        "tray.full.fill",
        "doc.text.fill",
        "book.pages.fill",
        "text.book.closed.fill",
        "graduationcap.fill",
        "pencil.and.scribble",
        "highlighter",
        "pin.fill",
        "star.fill",
        "flag.fill",
        "bolt.fill",
        "target",
        "checkmark.seal.fill",
        "calendar",
        "clock.fill",
        "leaf.fill",
        "drop.fill",
        "flame.fill",
        "sparkles",
    ]

    // MARK: Adaptive surfaces

    static var windowBackground: Color {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
        #else
            Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var cardBackground: Color {
        #if os(macOS)
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    let isDark =
                        appearance.bestMatch(from: [.darkAqua, .aqua])
                        == .darkAqua

                    return isDark
                        ? NSColor(
                            srgbRed: 0.190,
                            green: 0.176,
                            blue: 0.161,
                            alpha: 1
                        )
                        : NSColor(
                            srgbRed: 1,
                            green: 1,
                            blue: 1,
                            alpha: 1
                        )
                }
            )
        #else
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(
                            red: 0.170,
                            green: 0.158,
                            blue: 0.145,
                            alpha: 1
                        )
                        : .secondarySystemGroupedBackground
                }
            )
        #endif
    }

    static var fieldBackground: Color {
        Color.primary.opacity(0.045)
    }

    static var hairline: Color {
        Color.primary.opacity(0.09)
    }

    // MARK: Deterministic subject styling

    /// A stable (not process-randomized) hash so a subject keeps the same
    /// color and symbol between launches and across devices.
    static func stableIndex(for text: String, count: Int) -> Int {
        guard count > 0 else { return 0 }

        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }

        return Int(hash % UInt64(count))
    }

    static func style(for name: String) -> SubjectStyle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.isEmpty ? "Untitled" : trimmed
        let lowercase = key.lowercased()

        let symbol =
            symbolOverride(for: lowercase)
            ?? subjectSymbols[stableIndex(for: key, count: subjectSymbols.count)]

        return SubjectStyle(
            symbol: symbol,
            tint: palette[stableIndex(for: key, count: palette.count)]
        )
    }

    /// Well-known subject names get a symbol that actually describes them.
    private static func symbolOverride(for name: String) -> String? {
        let rules: [([String], String)] = [
            (["art", "paint", "design", "draw"], "paintpalette.fill"),
            (["bio", "cell", "genetic", "nature", "plant"], "leaf.fill"),
            (["math", "algebra", "calcul", "geometry"], "function"),
            (["physic", "chem", "science", "astronom"], "atom"),
            (
                [
                    "japan", "language", "spanish", "french", "german",
                    "english", "chinese", "korean", "italian", "latin",
                ],
                "text.book.closed.fill"
            ),
            (["history", "historic", "civil"], "clock.arrow.circlepath"),
            (["music", "piano", "guitar", "song"], "music.note"),
            (["geograph", "geo", "world", "country"], "globe.europe.africa.fill"),
            (["medic", "anatomy", "health"], "cross.case.fill"),
            (
                ["computer", "code", "program", "software", "web"],
                "chevron.left.forwardslash.chevron.right"
            ),
            (["econom", "business", "finance", "market"], "chart.line.uptrend.xyaxis"),
            (["law", "legal", "politic"], "scalemass.fill"),
            (["psych", "philosoph", "mind"], "brain.head.profile"),
            (["book", "literature", "read"], "book.closed.fill"),
        ]

        for (keywords, symbol) in rules
        where keywords.contains(where: { name.contains($0) }) {
            return symbol
        }

        return nil
    }
}

struct SubjectStyle {
    let symbol: String
    let tint: Color

    var gradient: LinearGradient {
        LinearGradient(
            colors: [tint, tint.mix(with: .black, by: 0.24)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Subject {
    /// The stored icon/color when set, otherwise a stable name-derived style.
    var style: SubjectStyle {
        let derived = KotoeTheme.style(for: name)

        return SubjectStyle(
            symbol: iconName ?? derived.symbol,
            tint: KotoeTheme.paletteColor(at: tintIndex) ?? derived.tint
        )
    }

    /// Palette index to preselect in the appearance editor.
    var effectiveTintIndex: Int {
        tintIndex
            ?? KotoeTheme.stableIndex(
                for: name,
                count: KotoeTheme.palette.count
            )
    }
}

extension FlashcardSet {
    /// Falls back to the subject's color so sets stay grouped visually until
    /// they are given a color of their own.
    var style: SubjectStyle {
        let fallbackTint = subject?.style.tint ?? KotoeTheme.accent

        return SubjectStyle(
            symbol: iconName ?? "rectangle.stack.fill",
            tint: KotoeTheme.paletteColor(at: tintIndex) ?? fallbackTint
        )
    }

    /// Palette index to preselect in the appearance editor.
    var effectiveTintIndex: Int {
        if let tintIndex { return tintIndex }
        if let subject { return subject.effectiveTintIndex }

        return KotoeTheme.stableIndex(
            for: name,
            count: KotoeTheme.palette.count
        )
    }
}

// MARK: - Ambient background

/// Soft brand-tinted backdrop used behind every screen. Pass a `tint` to make
/// a subject or set screen echo its chosen color.
struct AmbientBackground: View {

    var tint: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var primary: Color {
        tint ?? KotoeTheme.accent
    }

    var body: some View {
        ZStack {
            KotoeTheme.windowBackground

            if colorScheme == .light {
                KotoeTheme.paper.opacity(0.55)
            }

            RadialGradient(
                colors: [
                    primary.opacity(colorScheme == .dark ? 0.16 : 0.11),
                    .clear,
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 720
            )

            RadialGradient(
                colors: [
                    KotoeTheme.gold.opacity(colorScheme == .dark ? 0.09 : 0.13),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Icon tile

/// Rounded, gradient-filled SF Symbol tile. This is the main visual
/// building block for subjects, sets and content types.
struct IconTile: View {

    let symbol: String
    let tint: Color
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.96), tint.opacity(0.64)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)

            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.28), radius: size * 0.16, y: size * 0.07)
    }
}

// MARK: - Card surface

struct CardSurface: ViewModifier {

    @Environment(\.colorScheme) private var colorScheme

    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    var tint: Color? = nil

    private var tintOverlay: LinearGradient {
        LinearGradient(
            colors: [
                (tint ?? .clear).opacity(tint == nil ? 0 : 0.10),
                (tint ?? .clear).opacity(tint == nil ? 0 : 0.02),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(KotoeTheme.cardBackground)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: cornerRadius,
                            style: .continuous
                        )
                        .fill(tintOverlay)
                    }
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.30 : 0.06),
                        radius: 12,
                        y: 5
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        tint?.opacity(0.16) ?? KotoeTheme.hairline,
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func cardSurface(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 16,
        tint: Color? = nil
    ) -> some View {
        modifier(
            CardSurface(
                padding: padding,
                cornerRadius: cornerRadius,
                tint: tint
            )
        )
    }
}

// MARK: - Section header

struct SectionHeader: View {

    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))

            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.9)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Stat label

struct StatLabel: View {

    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Motion

struct PressableCardStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

struct HoverLift: ViewModifier {

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? 1.012 : 1)
            .brightness(isHovering ? 0.012 : 0)
            .animation(.snappy(duration: 0.22), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    /// Gentle lift for pointer-based platforms. Safe on touch platforms.
    func hoverLift() -> some View {
        modifier(HoverLift())
    }
}
