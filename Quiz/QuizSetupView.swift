//
//  QuizSetupView.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// Views/QuizSetupView.swift
import SwiftUI
import SwiftData

struct QuizSetupView: View {
    let kanjiSet: KanjiSet // KanjiSet yang dipilih pengguna.
    @Environment(\.modelContext) private var modelContext
    
    // State untuk mengontrol navigasi ke view kuis yang spesifik.
    // `navigationState` akan diisi ketika pengguna memilih untuk memulai atau melanjutkan kuis.
    @State private var navigationState: NavigationState?

    // Struktur helper untuk data navigasi.
    // MODIFIKASI: Tambahkan konformasi ke Hashable.
    struct NavigationState: Identifiable, Hashable {
        let id = UUID() // Diperlukan untuk Identifiable, juga Hashable.
        let mode: QuizMode // QuizMode adalah enum dengan rawValue String, jadi Hashable.
        let kanjiSet: KanjiSet // KanjiSet (@Model) adalah Hashable by PersistentIdentifier.

        // SwiftUI mungkin memerlukan implementasi hash(into:) dan == secara manual
        // jika tidak dapat mensintesisnya secara otomatis, terutama karena KanjiSet adalah kelas.
        // Namun, untuk SwiftData @Model, PersistentIdentifier biasanya cukup.
        // Jika error tetap ada, kita bisa implementasikan secara manual.
        // Untuk sekarang, kita coba tanpa implementasi manual dulu.

        // Contoh implementasi manual jika diperlukan (biasanya tidak untuk @Model):
        // static func == (lhs: NavigationState, rhs: NavigationState) -> Bool {
        //     return lhs.id == rhs.id && lhs.mode == rhs.mode && lhs.kanjiSet.persistentModelID == rhs.kanjiSet.persistentModelID
        // }

        // func hash(into hasher: inout Hasher) {
        //     hasher.combine(id)
        //     hasher.combine(mode)
        //     hasher.combine(kanjiSet.persistentModelID)
        // }
    }

    var body: some View {
        List {
            // Judul bagian, menampilkan nama KanjiSet.
            Section(header: Text("Mode Kuis untuk: \(kanjiSet.name)").font(.headline).padding(.top)) {
                // Iterasi melalui semua mode kuis yang tersedia (Pilihan Ganda, Input Teks).
                ForEach(QuizMode.allCases) { mode in
                    // Gunakan ModeQuizOptionsView untuk menampilkan opsi untuk setiap mode.
                    ModeQuizOptionsView(
                        kanjiSet: kanjiSet,
                        mode: mode,
                        navigationState: $navigationState // Binding untuk memicu navigasi.
                    )
                }
            }
        }
        .navigationTitle("Pengaturan Kuis")
        // Tujuan navigasi: ketika `navigationState` memiliki nilai, navigasi akan terjadi.
        .navigationDestination(item: $navigationState) { navState in
            // Tampilkan view kuis yang sesuai berdasarkan mode yang ada di `navState`.
            Group {
                switch navState.mode {
                case .multipleChoice:
                    MultipleChoiceQuizView(kanjiSet: navState.kanjiSet)
                case .textInput:
                    TextInputQuizView(kanjiSet: navState.kanjiSet)
                }
            }
        }
    }
}

// Subview untuk menampilkan opsi dan status untuk satu mode kuis.
struct ModeQuizOptionsView: View {
    let kanjiSet: KanjiSet
    let mode: QuizMode
    @Binding var navigationState: QuizSetupView.NavigationState? // Untuk memicu navigasi dari parent.

    @Environment(\.modelContext) private var modelContext
    @State private var session: QuizSessionModels? // Sesi kuis yang diambil untuk mode ini.

    // Properti komputasi untuk menentukan status sesi.
    var hasActiveSession: Bool { // Apakah ada sesi yang sedang berjalan (belum selesai).
        guard let s = session else { return false }
        return s.currentQuestionIndex < s.totalQuestions && s.totalQuestions > 0
    }
    var isCompleted: Bool { // Apakah sesi sudah selesai.
        guard let s = session else { return false } // Tidak ada sesi berarti belum selesai.
        return s.currentQuestionIndex >= s.totalQuestions && s.totalQuestions > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Nama dan deskripsi mode kuis.
            Text(mode.rawValue)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(mode.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 5)

            // Tampilkan progress bar jika sesi ada dan memiliki pertanyaan.
            if let s = session, s.totalQuestions > 0 {
                if hasActiveSession || isCompleted { // Tampilkan progress jika aktif atau sudah selesai.
                     VStack(alignment: .leading, spacing: 4) {
                        Text("Progres Tersimpan:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        // Gunakan progress bar yang sudah dibuat.
                        QuizSessionProgressBarSimplified(
                            correctAnswers: s.correctAnswers,
                            incorrectAnswers: s.incorrectAnswers,
                            totalQuestions: s.totalQuestions
                        )
                        // Tampilkan detail jumlah jawaban.
                        HStack {
                            Text("Benar: \(s.correctAnswers)").foregroundColor(.green)
                            Spacer()
                            Text("Salah: \(s.incorrectAnswers)").foregroundColor(.red)
                            Spacer()
                            Text("Sisa: \(max(0, s.totalQuestions - (s.correctAnswers + s.incorrectAnswers)))")
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                }
            }

            // Tombol aksi berdasarkan status sesi.
            HStack(spacing: 10) {
                Spacer() // Untuk menengahkan tombol jika hanya ada satu.
                if hasActiveSession {
                    // Tombol Lanjutkan Kuis: navigasi ke kuis untuk melanjutkan sesi.
                    Button {
                        self.navigationState = .init(mode: mode, kanjiSet: kanjiSet)
                    } label: {
                        Label("Lanjutkan", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)

                    // Tombol Mulai Ulang Kuis: hapus sesi lama, lalu navigasi untuk memulai baru.
                    Button {
                        restartQuizAndNavigate()
                    } label: {
                        Label("Ulangi", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                } else { // Tidak ada sesi aktif (baru atau sudah selesai).
                    // Tombol Mulai Kuis Baru (atau Mulai Lagi jika sudah selesai).
                    Button {
                        // Jika sesi sudah selesai, hapus dulu untuk memastikan mulai dari awal.
                        if isCompleted, session != nil {
                             QuizSessionManager.shared.clearSession(for: kanjiSet, mode: mode, modelContext: modelContext)
                             fetchSessionState() // Ambil ulang state sesi (akan jadi nil atau baru).
                        }
                        // Navigasi ke kuis (akan membuat sesi baru jika belum ada).
                        self.navigationState = .init(mode: mode, kanjiSet: kanjiSet)
                    } label: {
                        Label(isCompleted ? "Mulai Lagi" : "Mulai Kuis", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent) // Tombol utama.
                }
                Spacer() // Untuk menengahkan tombol.
            }
            .padding(.top, 5)
        }
        .padding(.vertical) // Padding vertikal untuk setiap opsi mode.
        .onAppear {
            fetchSessionState() // Ambil status sesi saat view muncul.
        }
    }

    // Fungsi untuk mengambil (atau membuat jika belum ada) status sesi untuk mode ini.
    private func fetchSessionState() {
        // getOrCreateSession akan membuat sesi jika belum ada, yang kita butuhkan untuk mengetahui totalQuestions dll.
        self.session = QuizSessionManager.shared.getOrCreateSession(for: kanjiSet, mode: mode, modelContext: modelContext)
    }

    // Fungsi untuk menghapus sesi saat ini dan kemudian menavigasi ke kuis (yang akan membuat sesi baru).
    private func restartQuizAndNavigate() {
        // 1. Hapus sesi yang ada untuk mode ini.
        QuizSessionManager.shared.clearSession(for: kanjiSet, mode: mode, modelContext: modelContext)
        
        // 2. Ambil ulang state sesi (sekarang seharusnya menjadi sesi baru yang kosong atau nil jika getOrCreateSession tidak langsung membuat).
        //    Ini membantu UI merefleksikan bahwa sesi lama sudah hilang sebelum navigasi.
        fetchSessionState()

        // 3. Navigasi ke view kuis. View kuis akan memanggil getOrCreateSession lagi,
        //    yang akan membuat sesi baru yang bersih karena yang lama sudah dihapus.
        self.navigationState = .init(mode: mode, kanjiSet: kanjiSet)
    }
}


