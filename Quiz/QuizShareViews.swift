//
//  SharedQuizViews.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// Views/SharedQuizViews.swift
import SwiftUI
import SwiftData

// View komponen untuk menampilkan header kuis (info soal dan skor).
struct QuizHeaderView: View {
    let session: QuizSessionModels // Untuk @Model, tidak perlu @ObservedObject

    var body: some View {
        HStack {
            Text("Soal: \(session.currentQuestionIndex + 1)/\(session.totalQuestions)")
            Spacer()
            Text("Skor: \(session.score)")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.bottom, 5)
    }
}

// View untuk menampilkan ringkasan hasil kuis setelah selesai.
struct QuizCompletionView: View {
    let session: QuizSessionModels // Untuk @Model, tidak perlu @ObservedObject
    var onRestart: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("🎉 Kuis Selesai! 🎉")
                    .font(.largeTitle)
                    .padding(.top)
                
                Text("Set: \(extractSetName(from: session.setId))")
                    .font(.title3)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Skor Akhir: \(session.score)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Divider()
                    HStack {
                        Text("Jawaban Benar:")
                        Spacer()
                        Text("\(session.correctAnswers) dari \(session.totalQuestions)")
                    }
                    HStack {
                        Text("Jawaban Salah:")
                        Spacer()
                        Text("\(session.incorrectAnswers)")
                    }
                    if session.totalQuestions > 0 {
                        let percentage = Double(session.correctAnswers) / Double(session.totalQuestions) * 100
                        HStack {
                            Text("Persentase Benar:")
                            Spacer()
                            Text("\(String(format: "%.1f", percentage))%")
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .shadow(radius: 3, x: 0, y: 2)

                Button {
                    onRestart()
                } label: {
                    Label("Ulangi Kuis Ini", systemImage: "arrow.clockwise.circle.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    onDismiss()
                } label: {
                    Label("Kembali ke Daftar Set", systemImage: "list.bullet.rectangle.portrait.fill")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func extractSetName(from setId: String) -> String {
        let parts = setId.split(separator: "_")
        if parts.count > 1 {
            return parts.dropFirst().joined(separator: " ")
        }
        return setId
    }
}

// MARK: - Progress Bar Sesi Kuis (Liquid Style)
// View untuk menampilkan progress bar cair dengan proporsi hijau (benar), merah (salah), dan abu-abu (sisa).
struct QuizSessionProgressBarSimplified: View {
    let correctAnswers: Int
    let incorrectAnswers: Int
    let totalQuestions: Int
    let barHeight: CGFloat = 12 // Tinggi progress bar yang diinginkan.

    var body: some View {
        GeometryReader { geometry in
            if totalQuestions > 0 {
                let totalWidth = geometry.size.width // Lebar total yang tersedia.
                
                // Hitung proporsi untuk setiap bagian.
                let correctProportion = CGFloat(correctAnswers) / CGFloat(totalQuestions)
                let incorrectProportion = CGFloat(incorrectAnswers) / CGFloat(totalQuestions)
                // Sisa pertanyaan adalah total dikurangi yang sudah dijawab (benar + salah).
                let answeredCount = correctAnswers + incorrectAnswers
                let remainingProportion = CGFloat(totalQuestions - answeredCount) / CGFloat(totalQuestions)

                // Hitung lebar aktual untuk setiap segmen berdasarkan proporsi dan lebar total.
                let correctWidth = totalWidth * correctProportion
                let incorrectWidth = totalWidth * incorrectProportion
                let remainingWidth = totalWidth * remainingProportion

                HStack(spacing: 0) { // Tidak ada jarak antar segmen agar terlihat cair.
                    // Segmen hijau untuk jawaban benar.
                    if correctWidth > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: correctWidth, height: barHeight)
                    }
                    
                    // Segmen merah untuk jawaban salah.
                    if incorrectWidth > 0 {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: incorrectWidth, height: barHeight)
                    }
                    
                    // Segmen abu-abu untuk pertanyaan yang belum dijawab.
                    // Pastikan remainingWidth dihitung dengan benar dan positif.
                    if remainingWidth > 0 && (correctWidth + incorrectWidth < totalWidth) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: remainingWidth, height: barHeight)
                    }
                }
                // Terapkan bentuk capsule (sudut membulat) ke seluruh HStack.
                .clipShape(Capsule())
                // Tambahkan border halus jika diinginkan.
                // .overlay(Capsule().stroke(Color.gray.opacity(0.5), lineWidth: 0.5))

            } else {
                // Jika tidak ada pertanyaan, tampilkan bar abu-abu penuh atau kosong.
                // Di sini kita tampilkan bar abu-abu sebagai placeholder.
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: barHeight)
                    .clipShape(Capsule())
            }
        }
        .frame(height: barHeight) // Atur tinggi keseluruhan progress bar.
    }
}
