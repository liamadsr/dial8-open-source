import Foundation

struct TranscriptionHistoryItem: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval?
    
    init(text: String, timestamp: Date = Date(), duration: TimeInterval? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}