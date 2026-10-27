//
//  FlashcardSide.swift
//  Flash
//
//  Created by Simon Weber on 19.10.26.
//


import Foundation
import SwiftData
import PencilKit

@Model
final class FlashcardSide {

    var id: UUID = UUID()

    var role: FlashcardSideRole = FlashcardSideRole.front
    
    var contentType: FlashcardContentType =
        FlashcardContentType.richText

    /// Backing value of `displayMode`. Optional because stores created before
    /// the field existed have no value for it; `nil` reads as `.editor`.
    var displayModeStorage: RichTextDisplayMode? = nil

    /// How the text editor shows this side's content. Part of the record so
    /// the choice is remembered per side and syncs through iCloud.
    var displayMode: RichTextDisplayMode {
        get { displayModeStorage ?? .editor }
        set { displayModeStorage = newValue }
    }

    // MARK: Content

    /// Rich text serialized as RTF or another chosen attributed-string format.
    var richTextData: Data?

    /// Legacy inline image data. New photos are written to `MediaStore` and
    /// referenced by `mediaFileName`; this stays for cards created earlier.
    var imageData: Data?

    /// Legacy inline PencilKit drawing data. New drawings are written to
    /// `MediaStore` and referenced by `mediaFileName`.
    var drawingData: Data?

    /// File name in `MediaStore` for image, drawing, or PDF content.
    var mediaFileName: String? = nil

    // MARK: Metadata

    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    // MARK: Relationships

    var flashcard: Flashcard?

    // MARK: Initialization

    init(
        role: FlashcardSideRole,
        contentType: FlashcardContentType = .richText,
        richTextData: Data? = nil,
        imageData: Data? = nil,
        drawingData: Data? = nil,
        mediaFileName: String? = nil
    ) {
        self.id = UUID()

        self.role = role
        self.contentType = contentType

        self.richTextData = richTextData
        self.imageData = imageData
        self.drawingData = drawingData
        self.mediaFileName = mediaFileName

        self.createdAt = .now
        self.modifiedAt = .now
    }

    // MARK: Content Updates

    func updateRichText(_ data: Data) {
        contentType = .richText

        richTextData = data
        imageData = nil
        drawingData = nil
        clearMediaFile()

        touch()
    }

    /// Stores a photo at its original resolution in the media folder.
    @discardableResult
    func updateImage(_ data: Data) -> Bool {
        guard
            let name = MediaStore.save(
                data: data,
                fileExtension: MediaStore.imageExtension(for: data)
            )
        else {
            return false
        }

        replaceMedia(with: name, contentType: .image)
        return true
    }

    /// Stores encoded PencilKit drawing data in the media folder.
    @discardableResult
    func updateDrawing(_ data: Data) -> Bool {
        guard let name = MediaStore.save(data: data, fileExtension: "pkdrawing")
        else {
            return false
        }

        replaceMedia(with: name, contentType: .drawing)
        return true
    }

    /// Stores a PDF document in the media folder.
    @discardableResult
    func updatePDF(_ data: Data) -> Bool {
        guard let name = MediaStore.save(data: data, fileExtension: "pdf")
        else {
            return false
        }

        replaceMedia(with: name, contentType: .pdf)
        return true
    }

    func clearContent() {
        richTextData = nil
        imageData = nil
        drawingData = nil
        clearMediaFile()

        touch()
    }

    // MARK: Media Storage

    private func replaceMedia(
        with name: String,
        contentType: FlashcardContentType
    ) {
        let previousName = mediaFileName

        self.contentType = contentType
        richTextData = nil
        imageData = nil
        drawingData = nil
        mediaFileName = name

        if let previousName, previousName != name {
            MediaStore.remove(named: previousName)
        }

        touch()
    }

    private func clearMediaFile() {
        guard let mediaFileName else { return }
        MediaStore.remove(named: mediaFileName)
        self.mediaFileName = nil
    }

    private func touch() {
        modifiedAt = .now
        flashcard?.modifiedAt = .now
    }
}

// MARK: - Media Access

extension FlashcardSide {

    /// Whether image content exists, including an iCloud placeholder that has
    /// not been downloaded yet.
    var hasImage: Bool {
        guard contentType == .image else { return false }

        if let mediaFileName {
            return MediaStore.hasFile(named: mediaFileName)
        }
        return imageData != nil
    }

    /// Whether drawing content exists, including an iCloud placeholder.
    var hasDrawing: Bool {
        if let mediaFileName {
            return MediaStore.hasFile(named: mediaFileName)
        }
        return drawingData != nil
    }

    /// Whether PDF content exists, including an iCloud placeholder.
    var hasPDF: Bool {
        guard contentType == .pdf, let mediaFileName else { return false }
        return MediaStore.hasFile(named: mediaFileName)
    }

    /// Image bytes already on this device, falling back to legacy inline data.
    var storedImageData: Data? {
        if let mediaFileName {
            return MediaStore.dataIfDownloaded(named: mediaFileName)
        }
        return imageData
    }

    /// Drawing bytes already on this device, falling back to legacy inline
    /// data.
    var storedDrawingData: Data? {
        if let mediaFileName {
            return MediaStore.dataIfDownloaded(named: mediaFileName)
        }
        return drawingData
    }

    /// Loads image bytes, waiting for an iCloud Drive download when needed.
    func loadImageData() async -> Data? {
        if let mediaFileName {
            return await MediaStore.loadData(named: mediaFileName) ?? imageData
        }
        return imageData
    }

    /// Removes the stored media file without altering the rest of the model.
    /// Call this before the side is deleted.
    func removeMediaFile() {
        guard let mediaFileName else { return }
        MediaStore.remove(named: mediaFileName)
        self.mediaFileName = nil
    }

    /// Loads drawing bytes, waiting for an iCloud Drive download when needed.
    func loadDrawingData() async -> Data? {
        if let mediaFileName {
            return await MediaStore.loadData(named: mediaFileName) ?? drawingData
        }
        return drawingData
    }
}

// MARK: - PencilKit Helpers

extension FlashcardSide {

    /// Returns the stored PencilKit drawing, if it is already on this device.
    var pencilKitDrawing: PKDrawing? {
        guard contentType == .drawing,
              let storedDrawingData else {
            return nil
        }

        return try? PKDrawing(data: storedDrawingData)
    }

    /// Stores a PencilKit drawing and updates modification dates.
    func updateDrawing(_ drawing: PKDrawing) {
        updateDrawing(drawing.dataRepresentation())
    }

    // MARK: - Rich Text

    /// The rich text of the side, decoded from the stored RTF. Falls back to
    /// the plain text when there is no RTF data.
    var attributedText: NSAttributedString {
        get {
            if let data = richTextData,
               let attributed = try? NSAttributedString(
                   data: data,
                   options: [.documentType: NSAttributedString.DocumentType.rtf],
                   documentAttributes: nil
               ) {
                return attributed
            }
            return NSAttributedString(string: plainText)
        }
        set {
            if let data = newValue.rtfData {
                updateRichText(data)
            } else {
                clearContent()
            }
        }
    }
}
