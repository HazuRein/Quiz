//
//  QuizModels.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// Models/QuizModels.swift
import Foundation
import SwiftData

// MARK: - Definisi Mode Kuis
// Enum untuk menentukan mode kuis yang bisa dipilih pengguna.
enum QuizMode: String, CaseIterable, Identifiable {
    case multipleChoice = "Pilihan Ganda" // Mode kuis dengan beberapa pilihan jawaban.
    case textInput = "Input Teks"      // Mode kuis dimana pengguna mengetik jawaban.

    var id: String { self.rawValue } // Untuk Identifiable.

    // Deskripsi singkat untuk setiap mode, bisa ditampilkan di UI.
    var description: String {
        switch self {
        case .multipleChoice:
            return "Pilih jawaban yang benar dari beberapa opsi."
        case .textInput:
            return "Ketik jawaban yang benar (misalnya, bacaan Hiragana atau arti)."
        }
    }
}

// MARK: - Model Sesi Kuis (untuk SwiftData)
// Model ini akan disimpan di database menggunakan SwiftData untuk melacak progres kuis pengguna.
@Model
class QuizSessionModels {
    @Attribute(.unique) var sessionId: String // ID unik untuk sesi kuis, format: "quiz_<setId>_<mode>"
    var setId: String                           // Identifier untuk KanjiSet (misalnya, "N5_Bab1")
    var score: Int                              // Skor total yang diperoleh pengguna dalam sesi ini.
    var currentQuestionIndex: Int               // Indeks pertanyaan saat ini yang sedang dihadapi pengguna.
    var totalQuestions: Int                     // Jumlah total pertanyaan dalam sesi kuis ini.
    var lastAccessDate: Date                    // Tanggal terakhir sesi ini diakses.
    var correctAnswers: Int                     // Jumlah jawaban benar.
    var incorrectAnswers: Int                   // Jumlah jawaban salah.
    var answeredQuestionIds: [String]           // Menyimpan ID Kanji yang sudah dijawab di sesi ini untuk menghindari pengulangan dalam logika tertentu.
    var hasQuestionOrderSaved: Bool             // Flag untuk menandakan apakah urutan pertanyaan untuk sesi ini sudah dibuat dan disimpan.

    // Konstruktor untuk membuat instance baru QuizSessionModels.
    init(sessionId: String, setId: String, totalQuestions: Int, score: Int = 0, currentQuestionIndex: Int = 0, correctAnswers: Int = 0, incorrectAnswers: Int = 0, answeredQuestionIds: [String] = [], hasQuestionOrderSaved: Bool = false) {
        self.sessionId = sessionId
        self.setId = setId
        self.totalQuestions = totalQuestions
        self.score = score
        self.currentQuestionIndex = currentQuestionIndex
        self.lastAccessDate = Date()
        self.correctAnswers = correctAnswers
        self.incorrectAnswers = incorrectAnswers
        self.answeredQuestionIds = answeredQuestionIds
        self.hasQuestionOrderSaved = hasQuestionOrderSaved
    }
}

// MARK: - Struktur Pertanyaan Kuis (NON-SwiftData, untuk state di View/ViewModel)
// Struktur ini digunakan untuk menampung data pertanyaan kuis yang akan ditampilkan di UI.
// Tidak disimpan langsung di SwiftData, tetapi dibuat secara dinamis.

// Struktur untuk pertanyaan Pilihan Ganda.
struct QuizQuestion: Identifiable {
    let id = UUID()                      // ID unik untuk setiap instance pertanyaan (berguna untuk UI Lists).
    let kanjiSource: Kanji               // Objek Kanji asli yang menjadi dasar pertanyaan ini.
    let questionText: String             // Teks pertanyaan yang akan ditampilkan (misal, "Apa arti dari...?").
    let options: [String]                // Array string yang berisi pilihan-pilihan jawaban.
    let correctAnswerIndex: Int          // Indeks dari jawaban yang benar dalam array `options`.
    let questionType: QuizQuestionTypeMC // Tipe pertanyaan pilihan ganda (misal, Kanji ke Arti).
}

// Enum untuk jenis-jenis pertanyaan dalam mode Pilihan Ganda.
enum QuizQuestionTypeMC: CaseIterable {
    case kanjiToMeaning // Dari Kanji, tebak artinya.
    case meaningToKanji // Dari Arti, tebak Kanji-nya.
    case kanjiToReading // Dari Kanji, tebak cara bacanya (Hiragana/Katakana).
}

// Struktur untuk pertanyaan Input Teks.
struct QuizTextInputQuestion: Identifiable {
    let id = UUID()                        // ID unik.
    let kanjiSource: Kanji                 // Objek Kanji asli.
    let questionText: String               // Teks pertanyaan (misal, "Ketik bacaan untuk Kanji ini:").
    let correctAnswerString: String        // Jawaban yang benar dalam bentuk string.
    let questionType: QuizQuestionTypeTI   // Tipe pertanyaan input teks.
}

// Enum untuk jenis-jenis pertanyaan dalam mode Input Teks.
enum QuizQuestionTypeTI: CaseIterable {
    case kanjiToReadingInput // Pengguna mengetik bacaan (Hiragana/Katakana).
    case kanjiToMeaningInput // Pengguna mengetik arti (misalnya, dalam bahasa Indonesia).
}
