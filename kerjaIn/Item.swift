//
//  Item.swift
//  kerjaIn
//
//  Created by Shafa Tiara on 04/09/26.
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
