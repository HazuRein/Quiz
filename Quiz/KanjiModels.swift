//
//  KanjiModels.swift
//  KanjiFlashcard
//
//  Created by Muhammad Ardiansyah on 11/05/25.
//

import Foundation
import SwiftData

@Model
class KanjiSet {
    var level: String
    var name: String
    var items: [Kanji]
    
    init(level: String, name: String, items: [Kanji] = []) {
        self.level = level
        self.name = name
        self.items = items
    }
}

@Model
class Kanji {
    @Attribute(.unique) var id: UUID
    var kanji: String
    var reading: String
    var meaning: String
    
    init(id: UUID, kanji: String, reading: String, meaning: String) {
        self.id = id
        self.kanji = kanji
        self.reading = reading
        self.meaning = meaning
    }
}
