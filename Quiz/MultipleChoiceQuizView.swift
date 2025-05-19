//
//  MultipleChoiceQuizView.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// Views/MultipleChoiceQuizView.swift
import SwiftUI

// View untuk menampilkan kuis mode pilihan ganda.
struct MultipleChoiceQuizView: View {
    let kanjiSet: KanjiSet // KanjiSet yang sedang dikuiskan.
    @Environment(\.modelContext) private var modelContext // Konteks SwiftData dari environment.
    @Environment(\.dismiss) private var dismiss // Aksi untuk menutup view ini.

    // State untuk data sesi dan pertanyaan kuis.
    @State private var quizSession: QuizSessionModels?
    @State private var currentQuestion: QuizQuestion?
    @State private var allQuestions: [QuizQuestion] = [] // Semua pertanyaan untuk sesi ini.

    // State untuk interaksi UI.
    @State private var selectedOptionIndex: Int? = nil // Indeks pilihan jawaban pengguna.
    @State private var showFeedback = false             // Apakah feedback (benar/salah) sedang ditampilkan.
    @State private var feedbackMessage = ""             // Pesan feedback.
    @State private var isAnswerCorrect: Bool? = nil    // Apakah jawaban terakhir benar.
    @State private var isLoading = true                 // Apakah data kuis sedang dimuat.
    @State private var isQuizFinished = false           // Apakah kuis telah selesai.

    var body: some View {
        VStack(spacing: 15) {
            if isLoading {
                ProgressView("Memuat Kuis Pilihan Ganda...") // Tampilan loading.
            } else if isQuizFinished, let session = quizSession {
                // Tampilan ketika kuis selesai.
                QuizCompletionView(session: session, onRestart: restartQuiz, onDismiss: { dismiss() })
            } else if let question = currentQuestion, let session = quizSession {
                // Tampilan utama kuis.
                QuizHeaderView(session: session) // Header menampilkan info soal dan skor.

                Text(question.questionText) // Teks pertanyaan.
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding()
                    .minimumScaleFactor(0.7) // Agar teks mengecil jika terlalu panjang.

                // Menampilkan pilihan jawaban sebagai tombol.
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, optionText in
                    Button {
                        if !showFeedback { // Hanya izinkan pemilihan jika feedback belum ditampilkan.
                            selectedOptionIndex = index
                        }
                    } label: {
                        Text(optionText)
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 50) // Ukuran tombol.
                            .background(determineOptionBackground(for: index, question: question)) // Warna latar belakang dinamis.
                            .foregroundColor(Color(UIColor.label)) // Warna teks agar kontras dengan background.
                            .cornerRadius(10)
                            .overlay( // Border untuk opsi yang dipilih.
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedOptionIndex == index && !showFeedback ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedOptionIndex == index && !showFeedback ? 2 : 1)
                            )
                    }
                    .disabled(showFeedback) // Nonaktifkan tombol jika feedback ditampilkan.
                }

                Spacer() // Mendorong tombol aksi ke bawah.

                if showFeedback {
                    // Tampilan feedback setelah jawaban diperiksa.
                    VStack { // Gunakan VStack untuk menata pesan feedback.
                        Text(feedbackMessage)
                            .font(.headline)
                            .foregroundColor(isAnswerCorrect == true ? .green : .red)
                        // Tampilkan arti Kanji jika ada dan belum termasuk di feedbackMessage utama.
                        // (Sudah dimodifikasi agar feedbackMessage mengandung arti)
                    }
                    .padding(.vertical)
                    
                    Button(session.currentQuestionIndex + 1 >= session.totalQuestions ? "Lihat Hasil" : "Lanjut") {
                        proceedToNextQuestionOrFinish()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                } else {
                    // Tombol untuk memeriksa jawaban.
                    Button("Periksa Jawaban") {
                        checkAnswer()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedOptionIndex == nil) // Nonaktifkan jika belum ada jawaban dipilih.
                    .padding(.bottom)
                }
            } else {
                // Tampilan jika tidak ada pertanyaan atau terjadi error.
                Text("Tidak ada pertanyaan tersedia atau kuis telah selesai.")
                Button("Kembali") { dismiss() }
            }
        }
        .padding()
        .onAppear(perform: setupQuiz) // Panggil setupQuiz saat view muncul.
        .navigationTitle("Kuis: \(kanjiSet.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Fungsi untuk menentukan warna latar belakang pilihan jawaban.
    func determineOptionBackground(for index: Int, question: QuizQuestion) -> Color {
        if showFeedback { // Jika feedback ditampilkan:
            if index == question.correctAnswerIndex {
                return .green.opacity(0.3) // Jawaban benar selalu hijau.
            } else if index == selectedOptionIndex && isAnswerCorrect == false {
                return .red.opacity(0.3) // Jawaban salah pengguna berwarna merah.
            }
        } else if selectedOptionIndex == index {
            return .blue.opacity(0.1) // Opsi yang dipilih pengguna sebelum dicek.
        }
        return Color(UIColor.secondarySystemBackground) // Warna default.
    }

    // Fungsi untuk menyiapkan data kuis.
    func setupQuiz() {
        isLoading = true
        isQuizFinished = false
        let sessionManager = QuizSessionManager.shared
        let session = sessionManager.getOrCreateSession(for: kanjiSet, mode: .multipleChoice, modelContext: modelContext)
        self.quizSession = session

        var orderedKanjis: [Kanji]
        if session.hasQuestionOrderSaved,
           let loadedOrder = sessionManager.loadQuizQuestionOrder(
                forQuizSessionId: session.sessionId,
                availableKanjis: kanjiSet.items,
                modelContext: modelContext
           ) {
            orderedKanjis = loadedOrder
        } else {
            orderedKanjis = kanjiSet.items.shuffled()
            sessionManager.saveQuizQuestionOrder(
                forQuizSessionId: session.sessionId,
                orderedKanjiIds: orderedKanjis.map { $0.id.uuidString },
                modelContext: modelContext
            )
             if !session.hasQuestionOrderSaved || session.currentQuestionIndex >= orderedKanjis.count {
                 session.currentQuestionIndex = 0; session.score = 0; session.correctAnswers = 0; session.incorrectAnswers = 0; session.answeredQuestionIds = []
                 try? modelContext.save()
             }
        }
        if session.totalQuestions != orderedKanjis.count {
             session.totalQuestions = orderedKanjis.count
             if session.currentQuestionIndex >= session.totalQuestions && session.totalQuestions > 0 {
                 session.currentQuestionIndex = session.totalQuestions - 1
             } else if session.totalQuestions == 0 {
                 session.currentQuestionIndex = 0
             }
             try? modelContext.save()
        }

        self.allQuestions = QuizGenerator().generateAllMultipleChoiceQuestions(fromKanjis: orderedKanjis, allKanjisInSet: kanjiSet.items)
        
        if self.allQuestions.isEmpty && !orderedKanjis.isEmpty {
            print("Gagal menghasilkan pertanyaan Pilihan Ganda meskipun ada Kanji terurut. Periksa QuizGenerator.")
        }
        
        if session.currentQuestionIndex >= session.totalQuestions && session.totalQuestions > 0 {
            isQuizFinished = true
        } else {
            updateCurrentQuestion()
        }
        isLoading = false
    }

    // Memperbarui state `currentQuestion`
    func updateCurrentQuestion() {
        guard let unwrappedQuizSession = quizSession, !allQuestions.isEmpty else {
            currentQuestion = nil
            if (quizSession?.totalQuestions ?? 0) > 0 {
                isQuizFinished = true
            }
            return
        }

        if unwrappedQuizSession.currentQuestionIndex < allQuestions.count && unwrappedQuizSession.currentQuestionIndex < unwrappedQuizSession.totalQuestions {
            currentQuestion = allQuestions[unwrappedQuizSession.currentQuestionIndex]
            selectedOptionIndex = nil
            showFeedback = false
            isAnswerCorrect = nil
            isQuizFinished = false
        } else {
            currentQuestion = nil
            isQuizFinished = true
        }
    }

    // Memeriksa jawaban pengguna.
    func checkAnswer() {
        guard let question = currentQuestion, let session = quizSession, let selectedIdx = selectedOptionIndex else { return }

        isAnswerCorrect = (selectedIdx == question.correctAnswerIndex)
        showFeedback = true

        // MODIFIKASI: feedbackMessage sekarang selalu menyertakan arti Kanji.
        let kanjiReading = question.kanjiSource.reading.isEmpty ? "Tidak ada arti" : question.kanjiSource.reading
        let kanjiMeaning = question.kanjiSource.meaning.isEmpty ? "Tidak ada arti" : question.kanjiSource.meaning
        let kanjiCharacter = question.kanjiSource.kanji // Ambil karakter Kanji

        if isAnswerCorrect == true {
            feedbackMessage = "Benar! ✅\nArti \"\(kanjiCharacter)\" : \(kanjiReading) \" : \(kanjiMeaning)"
        } else {
            let correctAnswerText = question.options[question.correctAnswerIndex]
            feedbackMessage = "Salah. Jawabannya: \(correctAnswerText)\nArti \"\(kanjiCharacter)\" : \(kanjiReading) \" : \(kanjiMeaning)"
        }

        QuizSessionManager.shared.markQuestionAsAnswered(session: session, kanjiId: question.kanjiSource.id.uuidString, modelContext: modelContext)
        QuizSessionManager.shared.updateSession(session: session, answeredCorrectly: isAnswerCorrect, modelContext: modelContext)
    }

    // Pindah ke pertanyaan berikutnya atau menyelesaikan kuis.
    func proceedToNextQuestionOrFinish() {
        guard let session = quizSession else { return }
        
        if session.currentQuestionIndex + 1 >= session.totalQuestions {
            isQuizFinished = true
        } else {
            QuizSessionManager.shared.incrementQuestionIndex(for: session, modelContext: modelContext)
            updateCurrentQuestion()
        }
    }
    
    // Mengulang kuis dari awal.
    func restartQuiz() {
        guard let session = quizSession else { return }
        session.currentQuestionIndex = 0
        session.score = 0
        session.correctAnswers = 0
        session.incorrectAnswers = 0
        session.answeredQuestionIds = []
        session.hasQuestionOrderSaved = false
        do {
            try modelContext.save()
            QuizSessionManager.shared.clearQuizQuestionOrder(forQuizSessionId: session.sessionId, modelContext: modelContext)
        } catch {
            print("Error saat menyimpan sesi untuk restart: \(error)")
        }
        setupQuiz()
    }
}
