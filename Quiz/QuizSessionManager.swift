//
//  QuizSessionManager.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// Managers/QuizSessionManager.swift
import Foundation
import SwiftData

// Kelas QuizSessionManager bertanggung jawab untuk mengelola sesi kuis.
// Ini termasuk membuat, mengambil, memperbarui, dan menghapus data sesi kuis.
class QuizSessionManager {
    static let shared = QuizSessionManager() // Singleton instance.

    private init() {} // Konstruktor privat untuk memastikan hanya ada satu instance.

    // Fungsi untuk menghasilkan ID unik untuk sebuah KanjiSet.
    // Format: "<level>_<name>" (contoh: "N5_Bab1").
    // Fungsi ini mungkin juga digunakan oleh FlipcardSessionManager Anda.
    func generateSetId(for set: KanjiSet) -> String {
        return "\(set.level)_\(set.name)"
    }

    // Fungsi internal untuk menghasilkan ID sesi kuis yang unik.
    // ID ini mencakup ID set dan mode kuis untuk memastikan sesi yang berbeda untuk mode yang berbeda.
    // Format: "quiz_<setId>_<mode_kuis_lowercase_dengan_underscore>" (contoh: "quiz_N5_Bab1_pilihan_ganda").
    private func generateQuizSessionId(forSetId setId: String, mode: QuizMode) -> String {
        let modeString = mode.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
        return "quiz_\(setId)_\(modeString)"
    }

    // Mengambil sesi kuis yang sudah ada atau membuat yang baru jika belum ada.
    // Parameter:
    //   - set: KanjiSet yang akan dikuiskan.
    //   - mode: Mode kuis yang dipilih (Pilihan Ganda atau Input Teks).
    //   - modelContext: Konteks SwiftData untuk operasi database.
    // Mengembalikan instance QuizSessionModels.
    func getOrCreateSession(for set: KanjiSet, mode: QuizMode, modelContext: ModelContext) -> QuizSessionModels {
        let setId = generateSetId(for: set)
        let quizSessionId = generateQuizSessionId(forSetId: setId, mode: mode)
        let totalKanjiInSet = set.items.count // Jumlah Kanji dalam set, digunakan untuk total pertanyaan.

        // Mencoba mencari sesi yang sudah ada di database.
        let predicate = #Predicate<QuizSessionModels> { sessionData in
            sessionData.sessionId == quizSessionId
        }
        let descriptor = FetchDescriptor<QuizSessionModels>(predicate: predicate)

        do {
            let existingSessions = try modelContext.fetch(descriptor)
            if let existingSession = existingSessions.first {
                // Jika sesi ditemukan, periksa apakah jumlah total pertanyaan dalam set berubah.
                // Jika berubah, progres sesi mungkin perlu direset.
                if existingSession.totalQuestions != totalKanjiInSet {
                    print("Jumlah Kanji dalam set \(setId) (mode: \(mode.rawValue)) telah berubah. Mereset progres sesi kuis.")
                    // Hapus urutan pertanyaan lama karena set berubah.
                    clearQuizQuestionOrder(forQuizSessionId: existingSession.sessionId, modelContext: modelContext, shouldSaveContext: false) // Jangan simpan dulu.
                    
                    // Update total pertanyaan dan reset progres.
                    existingSession.totalQuestions = totalKanjiInSet
                    existingSession.currentQuestionIndex = 0
                    existingSession.score = 0
                    existingSession.correctAnswers = 0
                    existingSession.incorrectAnswers = 0
                    existingSession.answeredQuestionIds = []
                    existingSession.hasQuestionOrderSaved = false // Urutan perlu dibuat ulang.
                }
                existingSession.lastAccessDate = Date() // Perbarui tanggal akses terakhir.
                try? modelContext.save() // Simpan perubahan (lastAccessDate atau reset di atas).
                print("Mengambil sesi kuis yang sudah ada: \(quizSessionId)")
                return existingSession
            }
        } catch {
            print("Error saat mengambil sesi kuis: \(error)")
        }

        // Jika tidak ada sesi yang ditemukan, buat sesi baru.
        print("Membuat sesi kuis baru: \(quizSessionId)")
        let newSession = QuizSessionModels(sessionId: quizSessionId, setId: setId, totalQuestions: totalKanjiInSet)
        modelContext.insert(newSession) // Masukkan sesi baru ke konteks.

        // Simpan konteks untuk menyimpan sesi baru ke database.
        do {
            try modelContext.save()
        } catch {
            print("Error saat menyimpan sesi kuis baru: \(error)")
        }
        return newSession
    }

    // Memperbarui data sesi kuis setelah pengguna menjawab pertanyaan.
    // Parameter:
    //   - session: Sesi QuizSessionModels yang akan diperbarui.
    //   - answeredCorrectly: Bool? yang menandakan apakah jawaban benar (nil jika pertanyaan diskip/belum dinilai).
    //   - modelContext: Konteks SwiftData.
    func updateSession(
        session: QuizSessionModels,
        answeredCorrectly: Bool?,
        modelContext: ModelContext
    ) {
        session.lastAccessDate = Date() // Selalu perbarui tanggal akses.

        if let wasCorrect = answeredCorrectly {
            if wasCorrect {
                session.correctAnswers += 1
                session.score += 10 // Skor bisa disesuaikan sesuai aturan permainan Anda.
            } else {
                session.incorrectAnswers += 1
            }
        }
        // currentQuestionIndex diperbarui secara terpisah oleh fungsi incrementQuestionIndex.

        do {
            try modelContext.save() // Simpan perubahan ke database.
        } catch {
            print("Error saat memperbarui sesi kuis \(session.sessionId): \(error)")
        }
    }
    
    // Menaikkan indeks pertanyaan saat ini dalam sesi.
    func incrementQuestionIndex(for session: QuizSessionModels, modelContext: ModelContext) {
        // Hanya increment jika belum mencapai akhir kuis.
        if session.currentQuestionIndex < session.totalQuestions {
            session.currentQuestionIndex += 1
            session.lastAccessDate = Date() // Perbarui juga tanggal akses terakhir.
            do {
                try modelContext.save()
            } catch {
                 print("Error saat menyimpan sesi setelah menaikkan indeks pertanyaan: \(error)")
            }
        }
    }

    // Menandai sebuah pertanyaan (berdasarkan ID Kanji) sebagai telah dijawab dalam sesi ini.
    func markQuestionAsAnswered(session: QuizSessionModels, kanjiId: String, modelContext: ModelContext) {
        if !session.answeredQuestionIds.contains(kanjiId) {
            session.answeredQuestionIds.append(kanjiId)
            // Biasanya dipanggil bersama updateSession, jadi penyimpanan bisa digabung di sana
            // atau jika ini adalah satu-satunya perubahan, perlu di-save.
            // Untuk saat ini, asumsikan save akan dilakukan oleh updateSession atau pemanggil.
        }
    }

    // Menghapus progres sesi kuis untuk sebuah KanjiSet dan mode tertentu.
    func clearSession(for set: KanjiSet, mode: QuizMode, modelContext: ModelContext) {
        let setId = generateSetId(for: set)
        let quizSessionId = generateQuizSessionId(forSetId: setId, mode: mode)
        
        clearSessionWithId(quizSessionId: quizSessionId, modelContext: modelContext)
        // Juga hapus urutan pertanyaan yang tersimpan untuk sesi ini.
        clearQuizQuestionOrder(forQuizSessionId: quizSessionId, modelContext: modelContext)
    }
    
    // Fungsi internal untuk menghapus sesi berdasarkan ID sesi kuisnya.
    private func clearSessionWithId(quizSessionId: String, modelContext: ModelContext) {
        let predicate = #Predicate<QuizSessionModels> { sessionData in
            sessionData.sessionId == quizSessionId
        }
        let descriptor = FetchDescriptor<QuizSessionModels>(predicate: predicate)
        do {
            let sessions = try modelContext.fetch(descriptor)
            if let sessionToDelete = sessions.first {
                modelContext.delete(sessionToDelete) // Hapus dari konteks.
                try modelContext.save() // Simpan perubahan ke database.
                print("Sesi kuis \(quizSessionId) telah dihapus.")
            }
        } catch {
            print("Error saat menghapus sesi kuis \(quizSessionId): \(error)")
        }
    }

    // MARK: - Manajemen Urutan Pertanyaan Kuis
    // Menggunakan model `IndexOrderModels` yang sudah ada untuk menyimpan urutan ID Kanji.
    // `forQuizSessionId` adalah ID unik yang sudah mencakup setId dan mode.

    // Menyimpan urutan ID Kanji untuk sebuah sesi kuis.
    // Ini memastikan bahwa jika pengguna melanjutkan kuis, urutan pertanyaannya tetap sama.
    func saveQuizQuestionOrder(forQuizSessionId quizSessionId: String, orderedKanjiIds: [String], modelContext: ModelContext) {
        // Hapus urutan lama jika ada, untuk memastikan hanya ada satu urutan per sesi kuis.
        clearQuizQuestionOrder(forQuizSessionId: quizSessionId, modelContext: modelContext, shouldSaveContext: false)

        // Buat objek IndexOrderModels baru dengan ID sesi kuis dan array ID Kanji.
        let order = IndexOrderModels(sessionId: quizSessionId, indexIds: orderedKanjiIds)
        modelContext.insert(order) // Masukkan ke konteks.
        
        // Update flag `hasQuestionOrderSaved` di QuizSessionModels terkait.
        updateQuizSessionOrderFlag(quizSessionId: quizSessionId, hasOrder: true, modelContext: modelContext, shouldSaveContext: false)

        do {
            try modelContext.save() // Simpan semua perubahan (order baru & flag sesi).
            print("Urutan pertanyaan kuis disimpan untuk \(quizSessionId).")
        } catch {
            print("Error saat menyimpan urutan pertanyaan kuis untuk \(quizSessionId): \(error)")
        }
    }

    // Memuat urutan Kanji yang tersimpan untuk sebuah sesi kuis.
    // Mengembalikan array Kanji yang sudah diurutkan, atau nil jika tidak ada urutan tersimpan atau terjadi error.
    func loadQuizQuestionOrder(forQuizSessionId quizSessionId: String, availableKanjis: [Kanji], modelContext: ModelContext) -> [Kanji]? {
        let predicate = #Predicate<IndexOrderModels> { orderData in
            orderData.sessionId == quizSessionId
        }
        let descriptor = FetchDescriptor<IndexOrderModels>(predicate: predicate)

        do {
            let orders = try modelContext.fetch(descriptor)
            guard let savedOrder = orders.first, !savedOrder.indexIds.isEmpty else {
                // Komentar ini bisa diaktifkan untuk debugging jika perlu.
                // print("Tidak ada urutan pertanyaan tersimpan ditemukan untuk \(quizSessionId).")
                return nil // Tidak ada urutan tersimpan.
            }

            // Buat dictionary dari Kanji yang tersedia untuk pencarian cepat berdasarkan ID.
            let kanjisById = Dictionary(uniqueKeysWithValues: availableKanjis.map { ($0.id.uuidString, $0) })
            var orderedKanjis: [Kanji] = []

            // Rekonstruksi array Kanji berdasarkan urutan ID yang tersimpan.
            for kanjiId in savedOrder.indexIds {
                if let kanji = kanjisById[kanjiId] {
                    orderedKanjis.append(kanji)
                } else {
                    // Jika ada ID Kanji yang tersimpan tapi Kanji-nya sudah tidak ada (misal dihapus dari set).
                    print("Peringatan: Kanji dengan ID \(kanjiId) tidak ditemukan. Urutan untuk \(quizSessionId) mungkin usang.")
                    // Hapus urutan yang tidak valid ini dan update flag.
                    clearQuizQuestionOrder(forQuizSessionId: quizSessionId, modelContext: modelContext)
                    updateQuizSessionOrderFlag(quizSessionId: quizSessionId, hasOrder: false, modelContext: modelContext)
                    return nil
                }
            }
            
            // Validasi tambahan: Apakah jumlah kanji yang di-load sesuai dengan total pertanyaan di sesi kuis?
            if let quizSession = fetchQuizSession(quizSessionId: quizSessionId, modelContext: modelContext) {
                if orderedKanjis.count != quizSession.totalQuestions {
                    print("Peringatan: Jumlah urutan yang dimuat (\(orderedKanjis.count)) tidak cocok dengan total pertanyaan sesi (\(quizSession.totalQuestions)) untuk \(quizSessionId). Membatalkan urutan.")
                    clearQuizQuestionOrder(forQuizSessionId: quizSessionId, modelContext: modelContext)
                    updateQuizSessionOrderFlag(quizSessionId: quizSessionId, hasOrder: false, modelContext: modelContext)
                    return nil
                }
            }

            print("Urutan pertanyaan kuis dimuat untuk \(quizSessionId) dengan \(orderedKanjis.count) pertanyaan.")
            return orderedKanjis
        } catch {
            print("Error saat memuat urutan pertanyaan kuis untuk \(quizSessionId): \(error)")
            return nil
        }
    }
    
    // Fungsi helper untuk mengambil instance QuizSessionModels berdasarkan ID.
    private func fetchQuizSession(quizSessionId: String, modelContext: ModelContext) -> QuizSessionModels? {
        let predicate = #Predicate<QuizSessionModels> { session in
            session.sessionId == quizSessionId
        }
        let descriptor = FetchDescriptor<QuizSessionModels>(predicate: predicate)
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error saat mengambil sesi kuis \(quizSessionId) untuk validasi: \(error)")
            return nil
        }
    }

    // Menghapus urutan pertanyaan yang tersimpan untuk sebuah sesi kuis.
    // Parameter `shouldSaveContext` menentukan apakah konteks harus disimpan setelah penghapusan.
    func clearQuizQuestionOrder(forQuizSessionId quizSessionId: String, modelContext: ModelContext, shouldSaveContext: Bool = true) {
        let predicate = #Predicate<IndexOrderModels> { orderData in
            orderData.sessionId == quizSessionId
        }
        let descriptor = FetchDescriptor<IndexOrderModels>(predicate: predicate)
        do {
            let orders = try modelContext.fetch(descriptor)
            if !orders.isEmpty { // Hanya lakukan jika ada order yang akan dihapus.
                for order in orders {
                    modelContext.delete(order) // Hapus dari konteks.
                }
                // Update flag di QuizSessionModels terkait.
                updateQuizSessionOrderFlag(quizSessionId: quizSessionId, hasOrder: false, modelContext: modelContext, shouldSaveContext: false) // Update flag sebelum save.
                
                if shouldSaveContext {
                    try modelContext.save() // Simpan perubahan ke database.
                }
                print("Urutan pertanyaan kuis yang tersimpan untuk \(quizSessionId) telah dihapus.")
            }
        } catch {
            print("Error saat menghapus urutan pertanyaan kuis untuk \(quizSessionId): \(error)")
        }
    }

    // Fungsi internal untuk memperbarui flag `hasQuestionOrderSaved` pada instance QuizSessionModels.
    private func updateQuizSessionOrderFlag(quizSessionId: String, hasOrder: Bool, modelContext: ModelContext, shouldSaveContext: Bool = true) {
        let predicate = #Predicate<QuizSessionModels> { sessionData in
            sessionData.sessionId == quizSessionId
        }
        let descriptor = FetchDescriptor<QuizSessionModels>(predicate: predicate)
        do {
            let sessions = try modelContext.fetch(descriptor)
            if let session = sessions.first {
                if session.hasQuestionOrderSaved != hasOrder { // Hanya update jika nilainya berbeda.
                    session.hasQuestionOrderSaved = hasOrder
                    if shouldSaveContext {
                        try modelContext.save() // Simpan perubahan ke database.
                    }
                }
            }
        } catch {
            print("Error saat memperbarui flag urutan sesi kuis untuk \(quizSessionId): \(error)")
        }
    }
}
