import SwiftUI
import AVFoundation
import Speech

struct SettingsListView: View {
    @Binding var selectedSettingsItem: SettingsItem?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Add a subtle header divider
            Divider()
                .background(Color.secondary.opacity(0.2))
                
            List(selection: $selectedSettingsItem) {
                ForEach(SettingsItem.defaultItems) { item in
                    SettingsRowView(item: item, isSelected: selectedSettingsItem == item)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                        .listRowSeparator(.hidden)
                        .onTapGesture {
                            selectedSettingsItem = item
                        }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.textBackgroundColor))
        }
        .background(Color(NSColor.textBackgroundColor))
        .onAppear {
            if selectedSettingsItem == nil {
                selectedSettingsItem = SettingsItem.voiceScribe
            }
        }
    }
}

struct SettingsRowView: View {
    let item: SettingsItem
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var microphonePermissionGranted = false
    @State private var accessibilityPermissionGranted = false
    @State private var speechRecognitionPermissionGranted = false
    
    var body: some View {
        HStack {
            Image(systemName: iconFor(item))
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text(item.title)
                .foregroundColor(isSelected ? .primary : .secondary)
            Spacer()
            
            // Show warning icon for settings when permissions are missing
            if item.type == .settings && !allPermissionsGranted {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .padding(.horizontal, 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06)
        } else if isHovered {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        } else {
            return .clear
        }
    }
    
    private func iconFor(_ item: SettingsItem) -> String {
        switch item.type {
        case .settings:
            return "gearshape"
        case .voiceScribe:
            return "waveform.circle"
        case .hotKeys:
            return "keyboard"
        case .textReplacements:
            return "textformat.alt"
        case .support:
            return "megaphone"
        default:
            return "circle"
        }
    }
    
    private var allPermissionsGranted: Bool {
        microphonePermissionGranted && 
        accessibilityPermissionGranted && 
        speechRecognitionPermissionGranted
    }
    
    private func checkPermissions() {
        // Use PermissionManager for all permission checks
        PermissionManager.shared.checkMicrophonePermission { granted in
            microphonePermissionGranted = granted
        }
        
        accessibilityPermissionGranted = PermissionManager.shared.checkAccessibilityPermission()
        
        PermissionManager.shared.checkSpeechRecognitionPermission { granted in
            speechRecognitionPermissionGranted = granted
        }
    }
}

struct SettingsCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading) {
                Text(title)
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(value)
                    .font(.title2)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
} 
