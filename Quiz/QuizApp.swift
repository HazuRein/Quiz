//
//  QuizApp.swift
//  Quiz
//
//  Created by Muhammad Ardiansyah on 19/05/25.
//

// QuizApp.swift
import SwiftUI
import SwiftData

@main
struct QuizApp: App {
    // Shared model container for the entire application.
    // Ensure ALL your @Model classes are listed in the schema.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            KanjiSet.self,
            Kanji.self,
            QuizSessionModels.self,    // Model for quiz sessions
            IndexOrderModels.self,     // Model for storing order (used by quiz and possibly flashcards)// Model for flashcard sessions (if still used)
            // Add any other @Model classes you have in your project here.
        ])
        // isStoredInMemoryOnly: true can be useful for testing, false for persistent storage.
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // This will crash the app if the container can't be created,
            // which is often desired during development to catch setup errors.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }() // The parentheses () are crucial to execute this closure.

    var body: some Scene {
        WindowGroup {
            // ContentView is your initial view that will display the KanjiSet list.
            ContentView()
        }
        // Apply the model container to the environment for all views in this WindowGroup.
        .modelContainer(sharedModelContainer)
    }
}


