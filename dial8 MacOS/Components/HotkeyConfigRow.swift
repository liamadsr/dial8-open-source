import SwiftUI

struct HotkeyConfigRow: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    let configuration: HotkeyConfiguration
    @State private var isLearning = false
    @State private var showingModeInfo = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Action Label (no dropdown)
            Text(configuration.action.description)
                .foregroundColor(.primary)
                .font(.system(size: 13))
                .frame(width: 120, alignment: .leading)

            Spacer()

            // 2. Key Combo Display with Edit Button
            HStack(spacing: 8) {
                if isLearning {
                    Text("Record Shortcut")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(keyComboComponents(configuration.keyCombo), id: \.self) { component in
                        Text(component)
                            .font(.system(size: 13))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(6)
                    }
                    
                    // Edit Button/Icon only shows when not learning
                    Button(action: {
                        isLearning = true
                        hotkeyManager.startLearning(for: configuration)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                            .background(Color(NSColor.windowBackgroundColor))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 4)
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // 3. Reset Button
            Button(action: {
                hotkeyManager.resetToDefaults()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                    Text("Reset")
                        .font(.system(size: 12))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 32)
        .onAppear {
            isLearning = (hotkeyManager.currentLearningConfig?.id == configuration.id)
        }
        .onChange(of: hotkeyManager.currentLearningConfig) { config in
            isLearning = (config?.id == configuration.id)
        }
    }

    private func keyComboComponents(_ keyCombo: KeyCombo) -> [String] {
        if keyCombo.keyCode == -1 && keyCombo.modifiers == 0 && keyCombo.additionalKeyCodes.isEmpty {
            return ["Unassigned"]
        }

        var components: [String] = []

        // Add modifier names (changed from symbols to text)
        if keyCombo.modifiers & CGEventFlags.maskCommand.rawValue != 0 { components.append("Command") }
        if keyCombo.modifiers & CGEventFlags.maskShift.rawValue != 0 { components.append("Shift") }
        if keyCombo.modifiers & CGEventFlags.maskControl.rawValue != 0 { components.append("Control") }
        if keyCombo.modifiers & CGEventFlags.maskAlternate.rawValue != 0 { components.append("Option") }
        if keyCombo.modifiers & CGEventFlags.maskSecondaryFn.rawValue != 0 { components.append("Fn") }

        // Add the primary key if it's not a modifier
        if keyCombo.keyCode != -1 && ![55, 56, 59, 58, 63].contains(keyCombo.keyCode) {
            components.append(KeyCodeMap.description(for: keyCombo.keyCode))
        }

        // Add additional keys
        for code in keyCombo.additionalKeyCodes {
            if ![55, 56, 59, 58, 63].contains(code) {
                components.append(KeyCodeMap.description(for: code))
            }
        }

        return components
    }

}
