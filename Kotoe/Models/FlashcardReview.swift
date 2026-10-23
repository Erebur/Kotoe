//
//  FlashcardReview.swift
//  Kōtoe
//
//  Created by Simon Weber on 22.10.26.
//

import Foundation
import SwiftData

/// One recorded mark from a study session. A card keeps a cascade-deleted
/// list of these, so its review history travels with it through iCloud.
@Model
final class FlashcardReview {

    var id: UUID = UUID()

    /// `true` when the card was marked as known, `false` for "Again".
    var correct: Bool = false

    /// When the mark was made.
    var reviewedAt: Date = Date.now

    var card: Flashcard?

    init(correct: Bool, reviewedAt: Date = .now) {
        self.id = UUID()

        self.correct = correct
        self.reviewedAt = reviewedAt
    }
}
