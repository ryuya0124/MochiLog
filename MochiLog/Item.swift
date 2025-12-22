//
//  Item.swift
//  MochiLog
//
//  Created by りゅうや on 2025/12/22.
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
