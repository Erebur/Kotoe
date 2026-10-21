//
//  FlashcardSideContentView.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//

import PencilKit
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - FlashcardSide helpers

extension FlashcardSide {

    /// Plain text of a rich-text side (decoded from the stored RTF).
    var plainText: String {
        guard
            let richTextData,
            let attributed = try? NSAttributedString(
                data: richTextData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        else { return "" }

        return attributed.string
    }

    /// Stores plain text as RTF, so a rich text editor can replace the
    /// plain text field later without changing the data format.
    func setPlainText(_ text: String) {
        contentType = .richText

        guard !text.isEmpty else {
            clearContent()
            return
        }

        let attributed = NSAttributedString(string: text)
        let data = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )

        if let data {
            updateRichText(data)
        }
    }

    /// Short description used in lists.
    var summary: String {
        switch contentType {
        case .richText:
            let text = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty
                ? String(localized: "shared.content.empty")
                : text
        case .image:
            return hasImage
                ? String(localized: "shared.contentType.image")
                : String(localized: "sideContent.summary.emptyImage")
        case .drawing:
            return hasDrawing
                ? String(localized: "shared.contentType.drawing")
                : String(localized: "sideContent.summary.emptyDrawing")
        case .pdf:
            return hasPDF
                ? String(localized: "shared.contentType.pdf")
                : String(localized: "sideContent.summary.emptyPDF")
        }
    }
}

// MARK: - Side content rendering

extension FlashcardContentType {

    var displayName: String {
        switch self {
        case .richText: return String(localized: "shared.contentType.text")
        case .image: return String(localized: "shared.contentType.image")
        case .drawing: return String(localized: "shared.contentType.drawing")
        case .pdf: return String(localized: "shared.contentType.pdf")
        }
    }

    var symbolName: String {
        switch self {
        case .richText: return "text.alignleft"
        case .image: return "photo"
        case .drawing: return "pencil.tip"
        case .pdf: return "doc.richtext"
        }
    }
}

struct FlashcardSideContentView: View {

    let side: FlashcardSide?
    var textFont: Font = .title2

    var body: some View {
        if let side {
            content(for: side)
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private func content(for side: FlashcardSide) -> some View {
        switch side.contentType {
        case .richText:
            let text = side.plainText
            if text.isEmpty {
                placeholder
            } else {
                Text(text)
                    .font(textFont)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }

        case .image:
            SideImageView(side: side)

        case .drawing:
            SideDrawingView(side: side)

        case .pdf:
            PDFSideView(fileName: side.mediaFileName)
                .clipShape(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
    }

    private var placeholder: some View {
        SidePlaceholder()
    }
}

// MARK: - Media rendering

private struct SidePlaceholder: View {

    var body: some View {
        Label("shared.content.empty", systemImage: "square.dashed")
            .font(.title3)
            .foregroundStyle(.tertiary)
    }
}

/// Loads image bytes from iCloud Drive (or legacy inline data) and shows a
/// progress indicator while a not-yet-downloaded file arrives.
private struct SideImageView: View {

    let side: FlashcardSide

    @State private var image: Image?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                SidePlaceholder()
            }
        }
        .task(id: side.modifiedAt) {
            await load()
        }
    }

    private func load() async {
        if let data = await side.loadImageData(),
           let loaded = platformImage(from: data) {
            image = loaded
        }

        isLoading = false
    }
}

/// Loads a PencilKit drawing and renders it in light mode so the ink matches
/// the white canvas on every device.
private struct SideDrawingView: View {

    let side: FlashcardSide

    @Environment(\.displayScale) private var displayScale

    @State private var image: Image?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .background(
                        Color.white,
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                SidePlaceholder()
            }
        }
        .task(id: side.modifiedAt) {
            await load()
        }
    }

    private func load() async {
        guard
            let data = await side.loadDrawingData(),
            let drawing = try? PKDrawing(data: data)
        else {
            isLoading = false
            return
        }

        image = renderedDrawing(drawing, scale: displayScale)
        isLoading = false
    }
}

/// Creates a SwiftUI image using the native image type of each platform.
private func platformImage(from data: Data) -> Image? {
    #if os(macOS)

    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)

    #else

    guard let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)

    #endif
}

/// Renders a PencilKit drawing to a SwiftUI image.
private func renderedDrawing(_ drawing: PKDrawing, scale: CGFloat) -> Image? {
    guard !drawing.bounds.isEmpty else { return nil }

    let rect = drawing.bounds.insetBy(dx: -16, dy: -16)

    #if os(macOS)

    let result = drawing.image(from: rect, scale: scale)
    return Image(nsImage: result)

    #else

    var result: UIImage?

    // Render in light mode so ink colors match the white canvas.
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
        result = drawing.image(from: rect, scale: scale)
    }

    guard let result else { return nil }
    return Image(uiImage: result)

    #endif
}

// MARK: - Drawing canvas (iOS and other UIKit platforms)

#if !os(macOS)

struct DrawingCanvas: UIViewRepresentable {

    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.overrideUserInterfaceStyle = .light
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.drawingPolicy = .anyInput
        canvas.drawing = drawing
        canvas.delegate = context.coordinator

        let toolPicker = PKToolPicker()
        toolPicker.addObserver(canvas)
        toolPicker.setVisible(true, forFirstResponder: canvas)
        context.coordinator.toolPicker = toolPicker

        DispatchQueue.main.async {
            canvas.becomeFirstResponder()
        }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        var toolPicker: PKToolPicker?

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

// MARK: - Drawing canvas (macOS)

#else

/// Mouse-driven PencilKit canvas.
///
/// `PKCanvasView` and `PKToolPicker` are iOS-only, but drawing strokes created
/// here are stored in the same `PKDrawing` format, so cards drawn on the Mac
/// sync to and render on iOS (and vice versa).
struct DrawingCanvas: NSViewRepresentable {

    @Binding var drawing: PKDrawing
    var inkColor: NSColor
    var lineWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.onChange = { newDrawing in
            context.coordinator.parent.drawing = newDrawing
        }
        view.apply(
            drawing: drawing,
            inkColor: inkColor,
            lineWidth: lineWidth
        )
        return view
    }

    func updateNSView(_ view: DrawingCanvasView, context: Context) {
        context.coordinator.parent = self
        view.onChange = { newDrawing in
            context.coordinator.parent.drawing = newDrawing
        }
        view.apply(
            drawing: drawing,
            inkColor: inkColor,
            lineWidth: lineWidth
        )
    }

    final class Coordinator {
        var parent: DrawingCanvas

        init(_ parent: DrawingCanvas) {
            self.parent = parent
        }
    }
}

final class DrawingCanvasView: NSView {

    var onChange: ((PKDrawing) -> Void)?

    private var drawing = PKDrawing()
    private var inkColor: NSColor = .black
    private var lineWidth: CGFloat = 4

    private var activePoints: [PKStrokePoint] = []
    private var strokeStart = Date()
    private var preview: PKDrawing?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    func apply(
        drawing newDrawing: PKDrawing,
        inkColor newColor: NSColor,
        lineWidth newWidth: CGFloat
    ) {
        inkColor = newColor
        lineWidth = newWidth
        drawing = newDrawing
        needsDisplay = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)

        let scale = window?.backingScaleFactor ?? 2
        let image = (preview ?? drawing).image(from: bounds, scale: scale)
        image.draw(
            in: bounds,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    // MARK: Mouse input

    override func mouseDown(with event: NSEvent) {
        strokeStart = Date()
        activePoints = [point(for: event)]
        preview = nil
        updatePreview()
    }

    override func mouseDragged(with event: NSEvent) {
        activePoints.append(point(for: event))
        updatePreview()
    }

    override func mouseUp(with event: NSEvent) {
        activePoints.append(point(for: event))

        if let stroke = makeStroke() {
            drawing = PKDrawing(strokes: drawing.strokes + [stroke])
            onChange?(drawing)
        }

        activePoints = []
        preview = nil
        needsDisplay = true
    }

    // MARK: Stroke building

    private func point(for event: NSEvent) -> PKStrokePoint {
        let location = convert(event.locationInWindow, from: nil)

        return PKStrokePoint(
            location: location,
            timeOffset: Date().timeIntervalSince(strokeStart),
            size: CGSize(width: lineWidth, height: lineWidth),
            opacity: 1,
            force: 1,
            azimuth: 0,
            altitude: .pi / 2
        )
    }

    private func makeStroke() -> PKStroke? {
        guard !activePoints.isEmpty else { return nil }

        // A single point has no length; duplicate it so a tap still leaves a dot.
        var points = activePoints
        if points.count == 1 {
            points.append(points[0])
        }

        let path = PKStrokePath(
            controlPoints: points,
            creationDate: strokeStart
        )

        return PKStroke(
            ink: PKInk(.pen, color: inkColor),
            path: path,
            transform: .identity,
            mask: nil
        )
    }

    private func updatePreview() {
        guard let stroke = makeStroke() else { return }

        preview = PKDrawing(strokes: drawing.strokes + [stroke])
        needsDisplay = true
    }
}

#endif

// MARK: - Drawing editor

struct DrawingEditorView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var drawing: PKDrawing
    private let onSave: (PKDrawing) -> Void

    #if os(macOS)
    @State private var inkColor: Color = .black
    @State private var lineWidth: Double = 4
    #endif

    init(initial: PKDrawing, onSave: @escaping (PKDrawing) -> Void) {
        _drawing = State(initialValue: initial)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            canvas
                .navigationTitle("drawingEditor.navigation.title")
                .inlineNavigationBarTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("shared.actions.cancel") { dismiss() }
                            .keyboardShortcut(.cancelAction)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("shared.actions.done") {
                            onSave(drawing)
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
        }
        .editorSheetSize(width: 780, height: 600)
        .tint(KotoeTheme.accent)
    }

    @ViewBuilder
    private var canvas: some View {
        #if os(macOS)

        VStack(spacing: 0) {
            DrawingCanvas(
                drawing: $drawing,
                inkColor: NSColor(inkColor),
                lineWidth: CGFloat(lineWidth)
            )
            .frame(minWidth: 400, minHeight: 300)

            Divider()

            HStack(spacing: 14) {
                ColorPicker(
                    "drawingEditor.toolbar.penColor",
                    selection: $inkColor
                )
                .labelsHidden()
                .help("drawingEditor.toolbar.penColorHelp")

                HStack(spacing: 8) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Slider(value: $lineWidth, in: 1...24)
                        .frame(width: 150)

                    Text(verbatim: lineWidthLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                }

                Spacer()

                Button {
                    undo()
                } label: {
                    Label(
                        "drawingEditor.toolbar.undo",
                        systemImage: "arrow.uturn.backward"
                    )
                }
                .disabled(drawing.strokes.isEmpty)

                Button(role: .destructive) {
                    drawing = PKDrawing()
                } label: {
                    Label("drawingEditor.toolbar.clear", systemImage: "trash")
                }
                .disabled(drawing.strokes.isEmpty)
            }
            .padding(14)
            .background(KotoeTheme.cardBackground)
        }

        #else

        DrawingCanvas(drawing: $drawing)
            .ignoresSafeArea(edges: .bottom)

        #endif
    }

    #if os(macOS)
    private var lineWidthLabel: String {
        String(
            localized: "drawingEditor.toolbar.lineWidth",
            defaultValue: "\(Int(lineWidth.rounded())) pt"
        )
    }

    private func undo() {
        guard !drawing.strokes.isEmpty else { return }
        drawing = PKDrawing(strokes: Array(drawing.strokes.dropLast()))
    }
    #endif
}
