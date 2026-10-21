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

    // MARK: Content

    /// Rich text serialized as RTF or another chosen attributed-string format.
    var richTextData: Data?

    /// Encoded image data, for example JPEG or PNG.
    var imageData: Data?

    /// Serialized PencilKit drawing from PKDrawing.dataRepresentation().
    var drawingData: Data?

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
        drawingData: Data? = nil
    ) {
        self.id = UUID()

        self.role = role
        self.contentType = contentType

        self.richTextData = richTextData
        self.imageData = imageData
        self.drawingData = drawingData

        self.createdAt = .now
        self.modifiedAt = .now
    }

    // MARK: Content Updates

    func updateRichText(_ data: Data) {
        contentType = .richText

        richTextData = data
        imageData = nil
        drawingData = nil

        modifiedAt = .now
        flashcard?.modifiedAt = .now
    }

    func updateImage(_ data: Data) {
        contentType = .image

        richTextData = nil
        imageData = data
        drawingData = nil

        modifiedAt = .now
        flashcard?.modifiedAt = .now
    }

    func updateDrawing(_ data: Data) {
        contentType = .drawing

        richTextData = nil
        imageData = nil
        drawingData = data

        modifiedAt = .now
        flashcard?.modifiedAt = .now
    }

    func clearContent() {
        richTextData = nil
        imageData = nil
        drawingData = nil

        modifiedAt = .now
        flashcard?.modifiedAt = .now
    }
}

// MARK: - PencilKit Helpers

extension FlashcardSide {

    /// Returns the stored PencilKit drawing, if available.
    var pencilKitDrawing: PKDrawing? {
        guard contentType == .drawing,
              let drawingData else {
            return nil
        }

        return try? PKDrawing(data: drawingData)
    }

    /// Stores a PencilKit drawing and updates modification dates.
    func updateDrawing(_ drawing: PKDrawing) {
        let data = drawing.dataRepresentation()

        if data.count > 700_000 {
            print(
                "[CloudKit] Drawing is \(data.count) bytes; "
                    + "CloudKit records are limited to 1 MB."
            )
        }

        updateDrawing(data)
    }
}
