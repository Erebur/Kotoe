//
//  LocalizedCounts.swift
//  Kōtoe
//
//  Shared pluralized counts for subjects, sets and cards. The catalog stores
//  the plural variations; keep the source keys in sync with
//  Localizable.xcstrings.
//

import Foundation

enum LocalizedCounts {

    static func subjects(_ count: Int) -> String {
        String(
            localized: "shared.counts.subjects",
            defaultValue: "\(count) subjects"
        )
    }

    static func sets(_ count: Int) -> String {
        String(
            localized: "shared.counts.sets",
            defaultValue: "\(count) sets"
        )
    }

    static func cards(_ count: Int) -> String {
        String(
            localized: "shared.counts.cards",
            defaultValue: "\(count) cards"
        )
    }
}
