import Foundation
import SwiftUI

/// Folder model for organizing meeting notes
class Folder: Identifiable, ObservableObject, Codable {
    let id: String
    @Published var name: String
    @Published var color: Color
    @Published var createdAt: Date
    @Published var updatedAt: Date
    
    // Parent folder reference (nil for root folders)
    @Published var parentId: String?
    
    // Children tracking
    @Published var noteIds: Set<String> = []
    
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, createdAt, updatedAt, parentId, noteIds
    }
    
    init(name: String, color: Color = .blue, parentId: String? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
        self.parentId = parentId
    }
    
    // Codable implementation
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        noteIds = try container.decodeIfPresent(Set<String>.self, forKey: .noteIds) ?? []
        
        // Decode color from hex string
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        self.color = Color(hex: colorHex) ?? .blue
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color.toHex(), forKey: .colorHex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(parentId, forKey: .parentId)
        try container.encode(noteIds, forKey: .noteIds)
    }
    
    // Update folder name
    func updateName(_ newName: String) {
        name = newName
        updatedAt = Date()
        objectWillChange.send()
    }
    
    // Update folder color
    func updateColor(_ newColor: Color) {
        color = newColor
        updatedAt = Date()
        objectWillChange.send()
    }
    
    // Add a note to this folder
    func addNote(noteId: String) {
        noteIds.insert(noteId)
        updatedAt = Date()
        objectWillChange.send()
    }
    
    // Remove a note from this folder
    func removeNote(noteId: String) {
        noteIds.remove(noteId)
        updatedAt = Date()
        objectWillChange.send()
    }
    
    // Check if folder contains a specific note
    func contains(noteId: String) -> Bool {
        noteIds.contains(noteId)
    }
}

// Color extension for hex conversion
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
    
    func toHex() -> String {
        #if os(macOS)
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        let r = Int(color.redComponent * 255)
        let g = Int(color.greenComponent * 255)
        let b = Int(color.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #endif
    }
}

// FolderStorage for persistence
class FolderStorage {
    static let shared = FolderStorage()
    
    private init() {}
    
    // Get the URL for the folders storage file
    private func getFoldersURL() throws -> URL {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FolderStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find application support directory"])
        }
        
        let dial8URL = appSupportURL.appendingPathComponent("Dial8", isDirectory: true)
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: dial8URL, withIntermediateDirectories: true)
        
        return dial8URL.appendingPathComponent("folders.json")
    }
    
    // Save all folders
    func saveFolders(_ folders: [Folder]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(folders)
        let url = try getFoldersURL()
        try data.write(to: url)
    }
    
    // Load all folders
    func loadFolders() async throws -> [Folder] {
        let url = try getFoldersURL()
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([Folder].self, from: data)
    }
}