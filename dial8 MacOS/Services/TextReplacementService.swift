import Foundation

/// Simple text replacement rule
struct TextReplacement: Codable, Identifiable {
    let id: UUID
    let shortcut: String        // What to replace (e.g., "PM", "shawn") 
    let replacement: String     // What to replace it with (e.g., "product manager", "Shaun")
    let enabled: Bool          // Whether this replacement is active
    
    init(shortcut: String, replacement: String, enabled: Bool = true) {
        self.id = UUID()
        self.shortcut = shortcut
        self.replacement = replacement
        self.enabled = enabled
    }
}

/// Simple service for managing text replacements
class TextReplacementService: ObservableObject {
    static let shared = TextReplacementService()
    
    @Published var replacements: [TextReplacement] = []
    @Published var isEnabled: Bool = true
    
    private let userDefaults = UserDefaults.standard
    private let replacementsKey = "textReplacements"
    private let enabledKey = "textReplacementsEnabled"
    
    private init() {
        loadReplacements()
        isEnabled = userDefaults.bool(forKey: enabledKey)
    }
    
    /// Apply text replacements to the given text
    func applyReplacements(to text: String) -> String {
        guard isEnabled && !replacements.isEmpty else { return text }
        
        var processedText = text
        let enabledReplacements = replacements.filter { $0.enabled }
        
        // Apply each replacement
        for replacement in enabledReplacements {
            processedText = processedText.replacingOccurrences(
                of: replacement.shortcut, 
                with: replacement.replacement,
                options: .caseInsensitive
            )
        }
        
        return processedText
    }
    
    /// Add a new replacement
    func addReplacement(_ replacement: TextReplacement) {
        replacements.append(replacement)
        saveReplacements()
    }
    
    /// Remove a replacement
    func removeReplacement(_ replacement: TextReplacement) {
        replacements.removeAll { $0.id == replacement.id }
        saveReplacements()
    }
    
    /// Set enabled state
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: enabledKey)
    }
    
    private func saveReplacements() {
        if let data = try? JSONEncoder().encode(replacements) {
            userDefaults.set(data, forKey: replacementsKey)
        }
    }
    
    private func loadReplacements() {
        guard let data = userDefaults.data(forKey: replacementsKey),
              let loadedReplacements = try? JSONDecoder().decode([TextReplacement].self, from: data) else {
            // Start with some default replacements
            replacements = [
                TextReplacement(shortcut: "PM", replacement: "product manager"),
                TextReplacement(shortcut: "CEO", replacement: "chief executive officer"),
                TextReplacement(shortcut: "btw", replacement: "by the way")
            ]
            return
        }
        
        replacements = loadedReplacements
    }
}