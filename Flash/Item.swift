//
//  Item.swift
//  Flash
//
//  Created by Simon Weber on 18.10.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
