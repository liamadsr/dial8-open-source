import Foundation
import SwiftUI

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    @Published var hotkeyConfigurations: [HotkeyConfiguration] = [] {
        didSet {
            print("📊 Configurations updated: \(hotkeyConfigurations.count) items")
            saveConfigurations()
        }
    }
    
    @Published var isRecordingHotkey = false
    @Published var currentLearningConfig: HotkeyConfiguration?
    
    init() {
        print("🚀 Initializing HotkeyManager")
        loadSavedConfigurations()
    }
    
    private func loadSavedConfigurations() {
        // Force reset to new defaults by checking against a version number
        let currentConfigVersion = 6 // Increment this when you want to force new defaults
        let savedConfigVersion = UserDefaults.standard.integer(forKey: "hotkeyConfigurationsVersion")
        
        if savedConfigVersion < currentConfigVersion {
            print("📢 Hotkey configuration version mismatch. Forcing reset to new defaults.")
            print("Previous version: \(savedConfigVersion), Current version: \(currentConfigVersion)")
            resetToDefaults()
            UserDefaults.standard.set(currentConfigVersion, forKey: "hotkeyConfigurationsVersion")
            return
        }
        
        if let data = UserDefaults.standard.data(forKey: "hotkeyConfigurations"),
           let configs = try? JSONDecoder().decode([HotkeyConfiguration].self, from: data) {
            // Migrate old configurations if needed
            let migratedConfigs = migrateConfigurations(configs)
            self.hotkeyConfigurations = migratedConfigs
            print("📥 Loaded \(migratedConfigs.count) configurations")
        } else {
            // If no saved configurations, set up defaults
            resetToDefaults()
            UserDefaults.standard.set(currentConfigVersion, forKey: "hotkeyConfigurationsVersion")
        }
    }
    
    private func migrateConfigurations(_ configs: [HotkeyConfiguration]) -> [HotkeyConfiguration] {
        // Check if we have the old single transcribe action
        if configs.count == 1 && configs[0].action == .transcribe {
            print("🔄 Migrating from old single transcribe hotkey to push-to-talk system")
            return createDefaultConfigurations()
        }
        
        // Check if we have push-to-talk configured
        let hasPushToTalk = configs.contains { $0.action == .pushToTalk }
        
        if hasPushToTalk {
            // We have the new push-to-talk action, keep the existing configuration
            // Filter out any toggle mode actions since we no longer use them
            return configs.filter { $0.action == .pushToTalk }
        }
        
        // Otherwise reset to defaults
        print("🔄 No push-to-talk configuration found, resetting to defaults")
        return createDefaultConfigurations()
    }
    
    func startLearning(for configuration: HotkeyConfiguration) {
        // print("🎯 Starting to learn hotkey for action: \(configuration.action)")
        currentLearningConfig = configuration
        isRecordingHotkey = true
    }
    
    func recordNewKeyCombo(_ keyCombo: KeyCombo) {
        guard let learningConfig = currentLearningConfig else {
            print("⚠️ No configuration is currently in learning mode")
            return
        }
        
        // For modifier-only combinations, ensure we capture all pressed modifiers
        let finalKeyCombo: KeyCombo
        if keyCombo.keyCode == -1 && keyCombo.modifiers != 0 {
            // This is a modifier-only combination
            let relevantModifiers: UInt64 = [
                CGEventFlags.maskCommand.rawValue,
                CGEventFlags.maskShift.rawValue,
                CGEventFlags.maskControl.rawValue,
                CGEventFlags.maskAlternate.rawValue,
                CGEventFlags.maskSecondaryFn.rawValue
            ].reduce(0, |)
            
            // Keep only the relevant modifier flags
            finalKeyCombo = KeyCombo(
                keyCode: -1,
                modifiers: keyCombo.modifiers & relevantModifiers
            )
        } else {
            finalKeyCombo = keyCombo
        }
        
        print("✍️ Recording final combo: \(finalKeyCombo.description) for action: \(learningConfig.action)")
        
        // Check for conflicts
        let hasConflict = hotkeyConfigurations.contains { config in
            config.id != learningConfig.id && config.keyCombo == finalKeyCombo
        }
        
        if hasConflict {
            print("⚠️ KeyCombo conflicts with existing configuration")
            return
        }
        
        // Update the configuration
        if let index = hotkeyConfigurations.firstIndex(where: { $0.id == learningConfig.id }) {
            var updatedConfig = hotkeyConfigurations[index]
            updatedConfig.keyCombo = finalKeyCombo
            hotkeyConfigurations[index] = updatedConfig
            print("✅ Updated configuration with new keyCombo")
        }
        
        stopLearning()
    }
    
    func stopLearning() {
        print("🛑 Stopping hotkey learning")
        isRecordingHotkey = false
        currentLearningConfig = nil
    }
    
    
    
    func checkForConflicts(_ keyCombo: KeyCombo) -> Bool {
        return hotkeyConfigurations.contains { $0.keyCombo == keyCombo }
    }
    
    func resetToDefaults() {
        print("🔄 Resetting to defaults")
        hotkeyConfigurations = createDefaultConfigurations()
        print("✅ Reset to defaults with \(hotkeyConfigurations.count) configurations")
    }
    
    private func createDefaultConfigurations() -> [HotkeyConfiguration] {
        return [
            // Default push-to-talk hotkey (Option only)
            HotkeyConfiguration(
                action: .pushToTalk,
                keyCombo: KeyCombo(
                    keyCode: -1,
                    modifiers: CGEventFlags.maskAlternate.rawValue
                ),
                isEnabled: true
            )
        ]
    }
    
    private func saveConfigurations() {
        if let encoded = try? JSONEncoder().encode(hotkeyConfigurations) {
            UserDefaults.standard.set(encoded, forKey: "hotkeyConfigurations")
            print("💾 Configurations saved")
        }
    }
    
    func findConfigurationForKeyCombo(modifiers: UInt64, keyCode: Int) -> HotkeyConfiguration? {
        // Create a mask for the relevant modifier flags
        let relevantModifiers: UInt64 = [
            CGEventFlags.maskCommand.rawValue,
            CGEventFlags.maskShift.rawValue,
            CGEventFlags.maskControl.rawValue,
            CGEventFlags.maskAlternate.rawValue,
            CGEventFlags.maskSecondaryFn.rawValue
        ].reduce(0, |)
        
        // Mask out irrelevant flags
        let maskedModifiers = modifiers & relevantModifiers
        
        for (index, config) in hotkeyConfigurations.enumerated() {
            let configModifiers = config.keyCombo.modifiers & relevantModifiers
        }
        
        let config = hotkeyConfigurations.first { config in
            // For modifier-only shortcuts (like Fn or Control)
            if config.keyCombo.keyCode == -1 {
                // Only match if:
                // 1. The configuration is modifier-only
                // 2. The pressed key is ONLY modifiers (keyCode == -1)
                // 3. The modifiers match exactly
                let configModifiers = config.keyCombo.modifiers & relevantModifiers
                let matches = keyCode == -1 && configModifiers == maskedModifiers
                return matches
            } else {
                // For key combinations (if we add support for them later)
                let configModifiers = config.keyCombo.modifiers & relevantModifiers
                let matches = config.keyCombo.keyCode == keyCode && 
                            configModifiers == maskedModifiers
                return matches
            }
        }
        
        return config
    }
    
    func toggleHotkeyEnabled(_ configuration: HotkeyConfiguration) {
        if let index = hotkeyConfigurations.firstIndex(where: { $0.id == configuration.id }) {
            var updatedConfig = hotkeyConfigurations[index]
            
            // Since we only have one hotkey now, always keep it enabled
            updatedConfig.isEnabled = true
            
            hotkeyConfigurations[index] = updatedConfig
            print("🔄 Toggled hotkey enabled state: \(updatedConfig.isEnabled)")
        }
    }
}
