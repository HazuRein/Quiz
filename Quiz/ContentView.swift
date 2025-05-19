//
//  ContentView.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// ContentView.swift (Dengan Integrasi DataManager)
import SwiftUI
import SwiftData

struct ContentView: View {
    // Query untuk mengambil semua KanjiSet dari database.
    // Diurutkan berdasarkan level, lalu nama.
    @Query(sort: [SortDescriptor(\KanjiSet.level), SortDescriptor(\KanjiSet.name)]) private var kanjiSets: [KanjiSet]
    @Environment(\.modelContext) private var modelContext

    // State untuk menandakan apakah proses impor sedang berjalan (opsional, untuk UI feedback).
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Group { // Menggunakan Group untuk logika kondisional pada konten List.
                if isImporting {
                    VStack {
                        ProgressView()
                        Text("Mengimpor data awal...")
                            .padding(.top)
                            .foregroundColor(.secondary)
                    }
                } else if kanjiSets.isEmpty {
                    // Tampilan jika tidak ada KanjiSet dan tidak sedang mengimpor.
                    ContentUnavailableView {
                        Label("Tidak Ada Set Kanji", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Silakan impor data awal untuk memulai atau tambahkan set baru.")
                    } actions: {
                        // Tombol untuk memicu impor data jika daftar kosong.
                        Button {
                            importInitialData()
                        } label: {
                            Text("Impor Data Awal dari JSON")
                                .padding(.horizontal)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Tampilan daftar KanjiSet jika sudah ada data.
                    List {
                        ForEach(kanjiSets) { set in
                            // Navigasi ke QuizSetupView saat sebuah set dipilih.
                            NavigationLink(value: set) {
                                VStack(alignment: .leading) {
                                    Text(set.name)
                                        .font(.headline)
                                    Text("Level: \(set.level) - \(set.items.count) Kanji")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                // Menampilkan pesan jika set kosong setelah impor
                                .overlay(alignment: .trailing) {
                                    if set.items.isEmpty {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 5)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Set Kanji Saya")
            // Tujuan navigasi untuk KanjiSet.
            .navigationDestination(for: KanjiSet.self) { kanjiSet in
                // Pastikan KanjiSet yang diteruskan memiliki item sebelum memulai kuis.
                if kanjiSet.items.isEmpty {
                    ContentUnavailableView("Set Kosong", systemImage: "tray.fill", description: Text("Set \"\(kanjiSet.name)\" tidak memiliki Kanji untuk dikuiskan."))
                } else {
                    QuizSetupView(kanjiSet: kanjiSet)
                }
            }
            .toolbar {
                // Tombol di toolbar untuk selalu bisa memicu impor data (misalnya untuk update atau reset).
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: importInitialData) {
                        Label("Impor Data JSON", systemImage: "arrow.down.doc.fill")
                    }
                    .disabled(isImporting) // Nonaktifkan tombol saat impor berjalan.
                }
            }
            // Panggil importDataIfNeeded saat view pertama kali muncul.
            .onAppear {
                DataManager.shared.deleteAllKanjiData(modelContext: modelContext)
                // Impor data secara otomatis jika database kosong.
                // Anda bisa juga memilih untuk tidak melakukan ini dan hanya mengandalkan tombol.
                if kanjiSets.isEmpty && !isImporting { // Cek juga isImporting untuk menghindari pemanggilan ganda
                    print("Tidak ada data KanjiSet, mencoba impor otomatis...")
                    importInitialData()
                }
            }
        }
    }

    // Fungsi untuk memanggil DataManager agar mengimpor data dari JSON.
    private func importInitialData() {
        isImporting = true
        // Langsung panggil di main thread.
        // Jika ini terlalu lama dan memblokir UI, kita perlu solusi yang lebih canggih
        // seperti DataManager menggunakan actor dan background ModelContext sendiri.
        DataManager.shared.importDataIfNeeded(modelContext: modelContext)
        isImporting = false
        print("Proses impor data selesai (dijalankan di main thread).")
    }
}

#Preview {
    ContentView()
}
