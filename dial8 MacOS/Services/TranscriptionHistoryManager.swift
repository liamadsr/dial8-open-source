import Foundation
import SwiftUI

class TranscriptionHistoryManager: ObservableObject {
    static let shared = TranscriptionHistoryManager()
    
    @Published var transcriptionHistory: [TranscriptionHistoryItem] = []
    
    private let maxHistoryItems = 5
    private let userDefaultsKey = "transcriptionHistory"
    
    private init() {
        loadHistory()
    }
    
    func addTranscription(_ text: String, duration: TimeInterval? = nil) {
        // Don't add empty transcriptions
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let historyItem = TranscriptionHistoryItem(text: text, duration: duration)
        
        // Add to beginning of array
        transcriptionHistory.insert(historyItem, at: 0)
        
        // Keep only the last maxHistoryItems
        if transcriptionHistory.count > maxHistoryItems {
            transcriptionHistory = Array(transcriptionHistory.prefix(maxHistoryItems))
        }
        
        saveHistory()
        
        print("📝 Added transcription to history: \(text.prefix(50))...")
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let items = try? JSONDecoder().decode([TranscriptionHistoryItem].self, from: data) {
            self.transcriptionHistory = items
            print("📥 Loaded \(items.count) transcription history items")
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(transcriptionHistory) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("💾 Saved transcription history")
        }
    }
    
    func clearHistory() {
        transcriptionHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("🗑️ Cleared transcription history")
    }
}