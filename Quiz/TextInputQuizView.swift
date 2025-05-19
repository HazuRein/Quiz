//
//  TextInputQuizView.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// Views/TextInputQuizView.swift
import SwiftUI

// View untuk menampilkan kuis mode input teks.
struct TextInputQuizView: View {
    let kanjiSet: KanjiSet // KanjiSet yang sedang dikuiskan.
    @Environment(\.modelContext) private var modelContext // Konteks SwiftData.
    @Environment(\.dismiss) private var dismiss // Aksi untuk menutup view.

    // State untuk data sesi dan pertanyaan.
    @State private var quizSession: QuizSessionModels?
    @State private var currentQuestion: QuizTextInputQuestion?
    @State private var allQuestions: [QuizTextInputQuestion] = []

    // State untuk interaksi UI.
    @State private var userAnswer: String = ""           // Teks jawaban dari pengguna.
    @State private var showFeedback = false             // Apakah feedback ditampilkan.
    @State private var feedbackMessage = ""             // Pesan feedback.
    @State private var isAnswerCorrect: Bool? = nil    // Apakah jawaban terakhir benar.
    @State private var isLoading = true                 // Apakah data kuis dimuat.
    @State private var isQuizFinished = false           // Apakah kuis selesai.
    @FocusState private var isTextFieldFocused: Bool    // Untuk mengontrol fokus pada TextField.

    var body: some View {
        VStack(spacing: 15) {
            if isLoading {
                ProgressView("Memuat Kuis Input Teks...") // Tampilan loading.
            } else if isQuizFinished, let session = quizSession {
                // Tampilan ketika kuis selesai.
                QuizCompletionView(session: session, onRestart: restartQuiz, onDismiss: { dismiss() })
            } else if let question = currentQuestion, let session = quizSession {
                // Tampilan utama kuis.
                QuizHeaderView(session: session) // Header info soal dan skor.

                Text(question.questionText) // Teks pertanyaan.
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding()
                    .minimumScaleFactor(0.7)

                // TextField untuk input jawaban pengguna.
                TextField("Ketik jawabanmu di sini", text: $userAnswer)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if !userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !showFeedback {
                            checkAnswer()
                        }
                    }
                    .disabled(showFeedback)

                Spacer()

                if showFeedback {
                    // Tampilan feedback.
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
                        isTextFieldFocused = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.bottom)
                }
            } else {
                // Tampilan jika tidak ada pertanyaan atau error.
                Text("Tidak ada pertanyaan tersedia atau kuis telah selesai.")
                Button("Kembali") { dismiss() }
            }
        }
        .padding()
        .onAppear {
            setupQuiz()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                 isTextFieldFocused = true
            }
        }
        .navigationTitle("Kuis: \(kanjiSet.name)")
        .navigationBarTitleDisplayMode(.inline)
    }

    // Fungsi untuk menyiapkan data kuis.
    func setupQuiz() {
        isLoading = true
        isQuizFinished = false
        let sessionManager = QuizSessionManager.shared
        let session = sessionManager.getOrCreateSession(for: kanjiSet, mode: .textInput, modelContext: modelContext)
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

        self.allQuestions = QuizGenerator().generateAllTextInputQuestions(fromKanjis: orderedKanjis)
        
        if self.allQuestions.isEmpty && !orderedKanjis.isEmpty {
            print("Gagal menghasilkan pertanyaan Input Teks meskipun ada Kanji terurut. Periksa QuizGenerator.")
        }

        if session.currentQuestionIndex >= session.totalQuestions && session.totalQuestions > 0 {
            isQuizFinished = true
        } else {
            updateCurrentQuestion()
        }
        isLoading = false
    }

    // Memperbarui state `currentQuestion` dan UI terkait.
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
            userAnswer = ""
            showFeedback = false
            isAnswerCorrect = nil
            isQuizFinished = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        } else {
            currentQuestion = nil
            isQuizFinished = true
        }
    }

    // Memeriksa jawaban pengguna.
    func checkAnswer() {
        guard let question = currentQuestion, let session = quizSession else { return }

        let trimmedUserAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = trimmedUserAnswer.lowercased() == question.correctAnswerString.lowercased()

        self.isAnswerCorrect = isCorrect
        showFeedback = true

        // MODIFIKASI: feedbackMessage sekarang selalu menyertakan arti Kanji.
        let kanjiMeaning = question.kanjiSource.meaning.isEmpty ? "Tidak ada arti" : question.kanjiSource.meaning
        let kanjiCharacter = question.kanjiSource.kanji // Ambil karakter Kanji

        if isCorrect {
            feedbackMessage = "Benar! ✅\nArti \"\(kanjiCharacter)\": \(kanjiMeaning)"
        } else {
            feedbackMessage = "Salah. Jawaban: \(question.correctAnswerString)\nArti \"\(kanjiCharacter)\": \(kanjiMeaning)"
        }
        
        QuizSessionManager.shared.markQuestionAsAnswered(session: session, kanjiId: question.kanjiSource.id.uuidString, modelContext: modelContext)
        QuizSessionManager.shared.updateSession(session: session, answeredCorrectly: isCorrect, modelContext: modelContext)
    }

    // Pindah ke pertanyaan berikutnya atau menyelesaikan kuis.
    func proceedToNextQuestionOrFinish() {
        guard let session = quizSession else { return }
        if session.currentQuestionIndex + 1 >= session.totalQuestions {
            isQuizFinished = true
            isTextFieldFocused = false
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
            print("Error saat menyimpan sesi untuk restart Input Teks: \(error)")
        }
        setupQuiz()
    }
}

