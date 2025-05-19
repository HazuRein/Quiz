//
//  QuizGenerator.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// Utils/QuizGenerator.swift
import Foundation

// Kelas QuizGenerator bertanggung jawab untuk membuat objek pertanyaan kuis
// (QuizQuestion untuk pilihan ganda, QuizTextInputQuestion untuk input teks)
// dari data Kanji yang ada.
class QuizGenerator {

    // MARK: - Pembuatan Pertanyaan Pilihan Ganda
    // Fungsi ini membuat satu pertanyaan pilihan ganda dari sebuah Kanji.
    // Parameter:
    //   - kanji: Kanji sumber untuk pertanyaan.
    //   - allKanjisInSet: Semua Kanji dalam set tersebut, digunakan untuk membuat pilihan jawaban yang salah (pengecoh).
    //   - forcedType: Opsional, untuk memaksa tipe pertanyaan tertentu (misal, selalu Kanji ke Arti).
    // Mengembalikan instance QuizQuestion, atau nil jika pertanyaan tidak dapat dibuat.
    func generateMultipleChoiceQuestion(from kanji: Kanji, allKanjisInSet: [Kanji], forcedType: QuizQuestionTypeMC? = nil) -> QuizQuestion? {
        // Tentukan tipe pertanyaan yang mungkin dibuat berdasarkan data yang tersedia pada Kanji.
        var possibleTypes = QuizQuestionTypeMC.allCases
        if kanji.reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            possibleTypes.removeAll { $0 == .kanjiToReading } // Hapus jika tidak ada data bacaan.
        }
        if kanji.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            possibleTypes.removeAll { $0 == .kanjiToMeaning || $0 == .meaningToKanji } // Hapus jika tidak ada data arti.
        }

        // Jika tidak ada tipe pertanyaan yang valid yang bisa dibuat (misal, Kanji tidak punya arti DAN bacaan).
        guard !possibleTypes.isEmpty else {
            // Komentar ini bisa diaktifkan untuk debugging.
            // print("Pilihan Ganda: Tidak ada tipe pertanyaan yang valid untuk Kanji \(kanji.kanji)")
            return nil
        }

        // Pilih tipe pertanyaan (dipaksa atau acak dari yang memungkinkan).
        let type = forcedType ?? possibleTypes.randomElement()!
        
        var questionText: String
        var correctAnswer: String
        var incorrectOptionSourceAttribute: (Kanji) -> String // Fungsi untuk mengambil atribut dari Kanji lain sebagai pengecoh.
        var attributeToCheckForIncorrectNotEmpty: (Kanji) -> String // Fungsi untuk memastikan Kanji pengecoh punya data relevan.

        // Tentukan teks pertanyaan, jawaban benar, dan sumber pengecoh berdasarkan tipe pertanyaan.
        switch type {
        case .kanjiToMeaning:
            questionText = "Apa arti dari kanji \"\(kanji.kanji)\"?"
            correctAnswer = kanji.meaning
            incorrectOptionSourceAttribute = { $0.meaning }
            attributeToCheckForIncorrectNotEmpty = { $0.meaning }
        case .meaningToKanji:
            questionText = "Kanji mana yang memiliki arti \"\(kanji.meaning)\"?"
            correctAnswer = kanji.kanji
            incorrectOptionSourceAttribute = { $0.kanji }
            attributeToCheckForIncorrectNotEmpty = { $0.kanji } // Karakter Kanji seharusnya selalu ada.
        case .kanjiToReading:
            questionText = "Bagaimana cara membaca kanji \"\(kanji.kanji)\"?"
            correctAnswer = kanji.reading
            incorrectOptionSourceAttribute = { $0.reading }
            attributeToCheckForIncorrectNotEmpty = { $0.reading }
        }

        let numberOfOptions = 4 // Jumlah total pilihan jawaban yang diinginkan (1 benar + 3 salah).
        var options: [String] = [correctAnswer] // Mulai dengan jawaban yang benar.

        // Filter Kanji lain untuk dijadikan sumber pengecoh.
        // Pengecoh tidak boleh sama dengan Kanji sumber, atributnya tidak boleh sama dengan jawaban benar,
        // dan harus memiliki data yang relevan (misal, punya arti jika soalnya tentang arti).
        let potentialIncorrectSources = allKanjisInSet.filter {
            let attributeValue = incorrectOptionSourceAttribute($0)
            let checkAttributeValue = attributeToCheckForIncorrectNotEmpty($0)
            return $0.id != kanji.id && // Bukan Kanji yang sama.
                   attributeValue != correctAnswer && // Atribut pengecoh tidak sama dengan jawaban benar.
                   !checkAttributeValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty // Pengecoh punya data yang relevan.
        }.shuffled() // Acak urutan sumber pengecoh.

        // Tambahkan pengecoh ke daftar pilihan sampai jumlah yang diinginkan tercapai.
        for incorrectKanji in potentialIncorrectSources {
            if options.count < numberOfOptions {
                let incorrectOption = incorrectOptionSourceAttribute(incorrectKanji)
                if !options.contains(incorrectOption) { // Pastikan pengecoh juga unik satu sama lain.
                    options.append(incorrectOption)
                }
            } else {
                break // Sudah cukup pilihan.
            }
        }

        // Jika jumlah pilihan masih kurang dari 2 (minimal 1 benar, 1 salah), pertanyaan tidak valid.
        if options.count < 2 {
            // Komentar ini bisa diaktifkan untuk debugging.
            // print("Pilihan Ganda: Tidak cukup opsi unik untuk Kanji \(kanji.kanji), tipe \(type). Dihasilkan: \(options.count)")
            return nil
        }
        // Peringatan jika jumlah opsi kurang dari yang diharapkan (misal, hanya 2 atau 3).
         if options.count < numberOfOptions {
            // print("Pilihan Ganda: Peringatan - jumlah opsi (\(options.count)) < \(numberOfOptions) untuk pertanyaan: \(questionText)")
        }

        options.shuffle() // Acak urutan akhir dari semua pilihan jawaban.
        
        // Pastikan jawaban benar ada dalam daftar pilihan setelah diacak (seharusnya selalu ada).
        guard let correctIdx = options.firstIndex(of: correctAnswer) else {
            // print("Pilihan Ganda: Jawaban benar '\(correctAnswer)' tidak ditemukan dalam opsi untuk Kanji \(kanji.kanji). Opsi: \(options)")
            return nil // Ini seharusnya tidak terjadi jika logika benar.
        }

        // Kembalikan objek QuizQuestion yang sudah jadi.
        return QuizQuestion(kanjiSource: kanji, questionText: questionText, options: options, correctAnswerIndex: correctIdx, questionType: type)
    }

    // Membuat daftar pertanyaan pilihan ganda untuk seluruh KanjiSet (atau dari daftar Kanji yang sudah diurutkan).
    func generateAllMultipleChoiceQuestions(fromKanjis kanjisToAsk: [Kanji], allKanjisInSet: [Kanji]) -> [QuizQuestion] {
        // Gunakan compactMap untuk membuat pertanyaan dan mengabaikan yang nil (gagal dibuat).
        return kanjisToAsk.compactMap { generateMultipleChoiceQuestion(from: $0, allKanjisInSet: allKanjisInSet) }
    }

    // MARK: - Pembuatan Pertanyaan Input Teks
    // Fungsi ini membuat satu pertanyaan input teks dari sebuah Kanji.
    // Parameter:
    //   - kanji: Kanji sumber untuk pertanyaan.
    //   - forcedType: Opsional, untuk memaksa tipe pertanyaan tertentu.
    // Mengembalikan instance QuizTextInputQuestion, atau nil jika pertanyaan tidak dapat dibuat.
    func generateTextInputQuestion(from kanji: Kanji, forcedType: QuizQuestionTypeTI? = nil) -> QuizTextInputQuestion? {
        // Tentukan tipe pertanyaan yang mungkin berdasarkan data yang tersedia.
        var possibleTypes = QuizQuestionTypeTI.allCases
        if kanji.reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            possibleTypes.removeAll { $0 == .kanjiToReadingInput }
        }
        if kanji.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            possibleTypes.removeAll { $0 == .kanjiToMeaningInput }
        }

        guard !possibleTypes.isEmpty else {
            // print("Input Teks: Tidak ada tipe pertanyaan yang valid untuk Kanji \(kanji.kanji)")
            return nil
        }

        let type = forcedType ?? possibleTypes.randomElement()!
        var questionText: String
        var correctAnswerString: String

        switch type {
        case .kanjiToReadingInput:
            questionText = "Ketik bacaan (Hiragana/Katakana) untuk kanji:\n\n\"\(kanji.kanji)\""
            correctAnswerString = kanji.reading
        case .kanjiToMeaningInput:
            // Asumsi arti dalam bahasa Indonesia. Sesuaikan jika perlu.
            questionText = "Ketik arti utama dalam bahasa Indonesia untuk kanji:\n\n\"\(kanji.kanji)\""
            correctAnswerString = kanji.meaning
        }

        return QuizTextInputQuestion(kanjiSource: kanji, questionText: questionText, correctAnswerString: correctAnswerString, questionType: type)
    }

    // Membuat daftar pertanyaan input teks untuk seluruh KanjiSet (atau dari daftar Kanji yang sudah diurutkan).
    func generateAllTextInputQuestions(fromKanjis kanjisToAsk: [Kanji]) -> [QuizTextInputQuestion] {
        return kanjisToAsk.compactMap { generateTextInputQuestion(from: $0) }
    }
}

