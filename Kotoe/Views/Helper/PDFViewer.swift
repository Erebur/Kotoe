//
//  PDFViewer.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import PDFKit
import SwiftUI

/// Renders a PDF stored in `MediaStore`.
///
/// The file lives in iCloud Drive, so it may still need to be downloaded on
/// this device. While that happens, a progress indicator is shown.
struct PDFSideView: View {

    let fileName: String?

    @State private var url: URL?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let url {
                PDFKitView(url: url)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(
                    "sideContent.media.unavailable",
                    systemImage: "doc.questionmark"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .task(id: fileName) {
            await load()
        }
    }

    private func load() async {
        url = nil

        guard let fileName else {
            isLoading = false
            return
        }

        isLoading = true
        let loaded = await MediaStore.loadURL(named: fileName)
        guard !Task.isCancelled else { return }

        url = loaded
        isLoading = false
    }
}

/// Full document viewer used when a PDF is opened from the card editor.
struct PDFDocumentView: View {

    let fileName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFSideView(fileName: fileName)
                .navigationTitle("pdfViewer.navigation.title")
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
        .editorSheetSize(width: 900, height: 720)
    }
}

// MARK: - PDFKit

#if os(macOS)

struct PDFKitView: NSViewRepresentable {

    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}

#else

struct PDFKitView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}

#endif

// MARK: - Previews

#Preview("PDF Side") {
    PDFSideView(fileName: nil)
        .frame(width: 320, height: 420)
}

#Preview("PDF Document") {
    PDFDocumentView(fileName: "preview.pdf")
}
