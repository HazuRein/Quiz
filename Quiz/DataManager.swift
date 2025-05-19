//
//  DataManager.swift
//  KanjiFlashcard
//
//  Created by Muhammad Ardiansyah on 11/05/25.
//
// DataManager.swift
import Foundation
import SwiftData

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

// Kelas DataManager bertanggung jawab untuk memuat data awal dari file JSON
// dan mengimpornya ke dalam database SwiftData.
class DataManager {
    static let shared = DataManager() // Singleton instance.
    
    private init() {} // Konstruktor privat untuk memastikan hanya ada satu instance.
    
    // Struktur data file yang akan diimpor.
    let kanjiFilesInfo: [KanjiFileInfo] = [
        KanjiFileInfo(level: "N5", files: ["kata_kerja_n5.json", "kata_sifat_na_n5.json", "kata_sifat_i_n5.json", "kata_benda_n5.json"]),
        KanjiFileInfo(level: "N4", files: ["kata_kerja_n4.json", "kata_sifat_na_n4.json", "kata_sifat_i_n4.json", "kata_benda_n4.json"]),
        KanjiFileInfo(level: "N3", files: ["kata_kerja_n3.json", "kata_benda_n3_i.json", "kata_benda_n3_ii.json"]),
        KanjiFileInfo(level: "Dummy", files: ["test_soal_3.json"]) // Pastikan ekstensi .json ada jika itu nama file sebenarnya.
    ]
    
    // Memuat data JSON dari sebuah file di dalam bundle aplikasi.
    func loadJSON(from filename: String) -> [KanjiJSONData]? {
        let resourceName = filename.replacingOccurrences(of: ".json", with: "")
        guard let fileURL = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            print("Tidak dapat menemukan file \(filename) di dalam bundle aplikasi.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode([KanjiJSONData].self, from: data)
            return jsonData
        } catch {
            print("Error saat men-decode JSON dari file \(filename): \(error)")
            return nil
        }
    }
    
    // Memeriksa apakah data untuk level dan nama file tertentu sudah ada di database.
    func doesDataExist(forLevel level: String, fileName: String, modelContext: ModelContext) -> Bool {
        let setName = fileName.replacingOccurrences(of: ".json", with: "")
        let predicate = #Predicate<KanjiSet> { set in
            set.level == level && set.name == setName
        }
        let descriptor = FetchDescriptor<KanjiSet>(predicate: predicate)
        
        do {
            let existingSets = try modelContext.fetch(descriptor)
            return !existingSets.isEmpty
        } catch {
            print("Error saat memeriksa data yang sudah ada: \(error)")
            return false
        }
    }
    
    // Mengimpor data dari semua file JSON yang didefinisikan di `kanjiFilesInfo` jika belum ada di database.
    func importDataIfNeeded(modelContext: ModelContext) {
        print("Memulai proses pemeriksaan dan impor data...")
        for levelInfo in kanjiFilesInfo {
            for fileName in levelInfo.files {
                if !doesDataExist(forLevel: levelInfo.level, fileName: fileName, modelContext: modelContext) {
                    importDataFromFile(level: levelInfo.level, fileName: fileName, modelContext: modelContext)
                } else {
                    print("Data untuk \(levelInfo.level) - \(fileName) sudah ada, impor dilewati.")
                }
            }
        }
        print("Proses pemeriksaan dan impor data selesai.")
    }
    
    // Mengimpor data dari satu file JSON spesifik ke database.
    // MODIFIKASI: Sekarang akan membuat objek Kanji dan menambahkannya ke KanjiSet.items.
    private func importDataFromFile(level: String, fileName: String, modelContext: ModelContext) {
        print("Mengimpor data untuk \(level) - \(fileName)...")
        
        guard let jsonDataArray = loadJSON(from: fileName) else {
            print("Gagal memuat data JSON dari \(fileName). Impor dibatalkan.")
            return
        }
        
        if jsonDataArray.isEmpty {
            print("File JSON \(fileName) kosong. Tidak ada data Kanji untuk diimpor ke dalam set.")
            // Tetap buat KanjiSet kosong jika file JSON ada tapi arraynya kosong
        }
        
        let setName = fileName.replacingOccurrences(of: ".json", with: "")
        let newKanjiSet = KanjiSet(level: level, name: setName, items: []) // Mulai dengan items kosong
        
        var importedKanjiCount = 0
        // Iterasi melalui setiap item JSON dan buat objek Kanji.
        for item in jsonDataArray {
            // Pemetaan field dari KanjiJSONData ke properti Kanji.
            // Pastikan pemetaan ini sesuai dengan makna data Anda.
            let kanjiItem = Kanji(
                id: UUID(), // ID unik untuk setiap Kanji.
                kanji: item.questionText,       // Diambil dari "Question Text" di JSON.
                reading: item.option1,          // Diambil dari "Option 1" di JSON.
                meaning: item.answerExplanation // Diambil dari "Answer explanation" di JSON.
            )
            newKanjiSet.items.append(kanjiItem) // Tambahkan Kanji ke daftar item set.
            importedKanjiCount += 1
        }
        
        // Masukkan KanjiSet baru (yang sekarang mungkin berisi item-item Kanji) ke konteks SwiftData.
        modelContext.insert(newKanjiSet)
        
        // Simpan perubahan ke database.
        do {
            try modelContext.save()
            if importedKanjiCount > 0 {
                print("Berhasil mengimpor \(importedKanjiCount) item Kanji untuk \(level) - \(setName) (dari file \(fileName)).")
            } else {
                // Jika jsonDataArray tidak kosong tapi tidak ada Kanji yang berhasil dibuat (misalnya karena logika filter tambahan di masa depan)
                // atau jika jsonDataArray memang kosong.
                print("Berhasil membuat KanjiSet untuk \(level) - \(setName), namun tidak ada item Kanji yang ditambahkan (file JSON berisi \(jsonDataArray.count) entri).")
            }
        } catch {
            print("Error saat menyimpan data yang diimpor untuk \(level) - \(setName): \(error)")
        }
    }

    // FUNGSI: Menghapus semua data KanjiSet dari database.
    func deleteAllKanjiData(modelContext: ModelContext) {
        print("Memulai proses penghapusan semua data KanjiSet...")
        let descriptor = FetchDescriptor<KanjiSet>()
        
        do {
            let allKanjiSets = try modelContext.fetch(descriptor)
            
            if allKanjiSets.isEmpty {
                print("Tidak ada data KanjiSet untuk dihapus.")
                return
            }
            
            for kanjiSet in allKanjiSets {
                modelContext.delete(kanjiSet)
            }
            
            try modelContext.save()
            print("Berhasil menghapus \(allKanjiSets.count) KanjiSet dan semua Kanji terkait.")
            
        } catch {
            print("Error saat menghapus semua data KanjiSet: \(error)")
        }
    }
}
