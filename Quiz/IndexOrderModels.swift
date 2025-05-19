//
//  CardOrderModels.swift
//  KanjiFlashcard
//
//  Created by Muhammad Ardiansyah on 12/05/25.
//

import Foundation
import SwiftData

// Model to save the order of cards in a session
@Model
class IndexOrderModels {
    var sessionId: String
    var indexIds: [String] // Store card IDs in order
    
    init(sessionId: String, indexIds: [String]) {
        self.sessionId = sessionId
        self.indexIds = indexIds
    }
}
