import Foundation

/// Text replacement rule with support for multiple trigger texts
struct TextReplacement: Codable, Identifiable {
    let id: UUID
    let triggerTexts: [String]  // Multiple texts that should be replaced (e.g., ["Sean", "Shawn", "Shaun"])
    let replacement: String     // What to replace them with (e.g., "Shaun")
    let enabled: Bool          // Whether this replacement is active
    
    init(triggerTexts: [String], replacement: String, enabled: Bool = true) {
        self.id = UUID()
        self.triggerTexts = triggerTexts.filter { !$0.isEmpty }
        self.replacement = replacement
        self.enabled = enabled
    }
    
    // Convenience initializer for single trigger text
    init(triggerText: String, replacement: String, enabled: Bool = true) {
        self.init(triggerTexts: [triggerText], replacement: replacement, enabled: enabled)
    }
    
    // Initializer for updating existing replacement (preserving ID and enabled state)
    init(id: UUID, triggerTexts: [String], replacement: String, enabled: Bool) {
        self.id = id
        self.triggerTexts = triggerTexts.filter { !$0.isEmpty }
        self.replacement = replacement
        self.enabled = enabled
    }
    
    // Legacy support for old data format during migration
    enum CodingKeys: String, CodingKey {
        case id, triggerTexts, replacement, enabled, shortcut
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        replacement = try container.decode(String.self, forKey: .replacement)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        
        // Try to decode new format first, fall back to legacy format
        if let triggerTexts = try? container.decode([String].self, forKey: .triggerTexts) {
            self.triggerTexts = triggerTexts.filter { !$0.isEmpty }
        } else if let shortcut = try? container.decode(String.self, forKey: .shortcut) {
            // Legacy format migration
            self.triggerTexts = [shortcut].filter { !$0.isEmpty }
        } else {
            self.triggerTexts = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(triggerTexts, forKey: .triggerTexts)
        try container.encode(replacement, forKey: .replacement)
        try container.encode(enabled, forKey: .enabled)
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
            // Apply each trigger text for this replacement
            for triggerText in replacement.triggerTexts {
                processedText = processedText.replacingOccurrences(
                    of: triggerText, 
                    with: replacement.replacement,
                    options: .caseInsensitive
                )
            }
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
    
    /// Update an existing replacement
    func updateReplacement(_ replacement: TextReplacement) {
        if let index = replacements.firstIndex(where: { $0.id == replacement.id }) {
            replacements[index] = replacement
            saveReplacements()
        }
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
            // Start with some default replacements showing the new capabilities
            replacements = [
                TextReplacement(triggerTexts: ["PM", "product mgr"], replacement: "product manager"),
                TextReplacement(triggerTexts: ["CEO", "chief exec"], replacement: "chief executive officer"),
                TextReplacement(triggerTexts: ["btw", "by the way"], replacement: "by the way"),
                TextReplacement(triggerTexts: ["Sean", "Shawn", "Shaun"], replacement: "Shaun")
            ]
            return
        }
        
        replacements = loadedReplacements
    }
}