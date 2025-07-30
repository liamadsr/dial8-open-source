import SwiftUI

struct HotKeysView: View {
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Push to Talk Hotkey
            if let pushToTalkConfig = hotkeyManager.hotkeyConfigurations.first(where: { $0.action == .pushToTalk }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push to Talk")
                                .font(.system(size: 14, weight: .medium))
                            Text("Hold to record, release to process")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HotkeyConfigRow(configuration: pushToTalkConfig)
                    }
                    
                    // Space bar lock instruction
                    HStack(spacing: 8) {
                        Image(systemName: "lock")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Text("Press Space while recording to lock (hands-free mode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 44) // Align with text above
                }
            }
            
            Divider()
            
            // Info text
            VStack(alignment: .leading, spacing: 4) {
                Text("Recording Controls:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Hold hotkey to record, release to stop")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Press Space while recording to lock (hands-free)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Press hotkey again to stop when locked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
} 