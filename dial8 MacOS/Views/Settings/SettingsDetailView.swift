import SwiftUI

struct SettingsItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let title: String
    let type: SettingsItemType
    var data: Any
    
    enum SettingsItemType: Hashable {
        case settings
        case voiceScribe
        case hotKeys
        case support
    }
    
    static func == (lhs: SettingsItem, rhs: SettingsItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(type)
        // We don't hash the data property since it's Any type
        // Instead, we rely on the id, title, and type for uniqueness
    }
    
    // Static items for reuse
    static let settings = SettingsItem(title: "App Settings", type: .settings, data: "settings")
    static let voiceScribe = SettingsItem(title: "Model Settings", type: .voiceScribe, data: "voice")
    static let hotKeys = SettingsItem(title: "Hotkeys", type: .hotKeys, data: "hotkeys")
    static let support = SettingsItem(title: "Support", type: .support, data: "support")
    
    static let defaultItems = [voiceScribe, hotKeys, settings, support]
}

struct SettingsDetailView: View {
    let item: SettingsItem
    @EnvironmentObject var audioManager: AudioManager
    @State private var selectedTab = "Settings"
    
    var body: some View {
        VStack(spacing: 0) {
            // Add a subtle header divider
            Divider()
                .background(Color.secondary.opacity(0.2))
                
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch item.type {
                    case .settings:
                        settingsContent
                    case .voiceScribe:
                        speechToTextContent
                    case .hotKeys:
                        hotKeysContent
                    case .support:
                        SupportView()
                    }
                }
                .padding()
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var speechToTextContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            WhisperModelSelectionView(
                showTitle: true,
                showDescription: true
            )
        }
        .padding()
    }
    
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Settings")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Configure general application settings")
                .font(.headline)
                .foregroundColor(.secondary)
            
            AppSetupView()
        }
        .padding()
    }
    
    
    private var hotKeysContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hot Keys")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Configure your keyboard shortcuts")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HotKeysView()
        }
        .padding()
    }
}

