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

// Struktur untuk informasi file JSON Kanji, digunakan oleh DataManager.
struct KanjiFileInfo: Identifiable {
    let id = UUID() // Diperlukan jika Identifiable.
    let level: String
    let files: [String]
}

// Struktur untuk merepresentasikan data dari file JSON.
// Pastikan nama field dan CodingKeys sesuai dengan struktur JSON Anda.
struct KanjiJSONData: Codable {
    var questionText: String
    var questionType: String
    var option1: String
    var option2: String?
    var option3: String?
    var option4: String?
    var option5: String?
    var correctAnswer: Int
    var timeInSeconds: Int
    var imageLink: String?
    var answerExplanation: String
    
    enum CodingKeys: String, CodingKey {
        case questionText = "Question Text"
        case questionType = "Question Type"
        case option1 = "Option 1"
        case option2 = "Option 2"
        case option3 = "Option 3"
        case option4 = "Option 4"
        case option5 = "Option 5"
        case correctAnswer = "Correct Answer"
        case timeInSeconds = "Time in seconds"
        case imageLink = "Image Link"
        case answerExplanation = "Answer explanation"
    }
}
