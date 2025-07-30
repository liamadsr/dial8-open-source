import SwiftUI

/// Control button component for the HUD
struct HUDControlButton: View {
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var interactionState: HUDInteractionState
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // Replace with a simple settings/info button instead of mode toggle
        Button(action: {
            // Open settings or show info popup
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
        }) {
            HStack(spacing: 4) {
                Image(systemName: "gear")
                    .font(HUDLayout.TextStyle.buttonIcon)
                    .foregroundColor(.primary)
                
                Text("Settings")
                    .font(HUDLayout.TextStyle.button)
                    .foregroundColor(.primary)
            }
            .padding(HUDLayout.buttonPadding)
            .background(Color.primary.opacity(interactionState.opacity(for: .modeButton)))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .scaleEffect(interactionState.scale(for: .modeButton))
        .onHover { hovering in
            if hovering {
                interactionState.handleMouseEnter(.modeButton)
                NSCursor.pointingHand.push()
            } else {
                interactionState.handleMouseExit(.modeButton)
                NSCursor.pop()
            }
        }
        .help("Open application settings")
    }
}

/// Bottom action buttons for the HUD
struct HUDBottomButtons: View {
    // Define button spacing and size constants
    private let bottomButtonSpacing: CGFloat = 8
    private let buttonHeight: CGFloat = 32
    
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var interactionState: HUDInteractionState
    
    // Create a computed property to access the accumulated text via AudioTranscriptionService
    private var accumulatedText: String {
        AudioTranscriptionService.shared.accumulatedText
    }
    
    var body: some View {
        HStack(spacing: bottomButtonSpacing) {
            // Clear button
            Button {
                withAnimation {
                    audioManager.clearAccumulatedText()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(HUDLayout.TextStyle.buttonIcon)
                        .foregroundColor(.primary)
                }
                .padding(HUDLayout.buttonPadding)
                .background(Color.primary.opacity(interactionState.opacity(for: .clearButton)))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .scaleEffect(interactionState.scale(for: .clearButton))
            .onHover { hovering in
                if hovering {
                    interactionState.handleMouseEnter(.clearButton)
                    NSCursor.pointingHand.push()
                } else {
                    interactionState.handleMouseExit(.clearButton)
                    NSCursor.pop()
                }
            }
            .help("Clear transcribed text")
            
            // Copy button
            Button {
                withAnimation {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(accumulatedText, forType: .string)
                    #endif
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(HUDLayout.TextStyle.buttonIcon)
                        .foregroundColor(.primary)
                }
                .padding(HUDLayout.buttonPadding)
                .background(Color.primary.opacity(interactionState.opacity(for: .copyButton)))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .scaleEffect(interactionState.scale(for: .copyButton))
            .onHover { hovering in
                if hovering {
                    interactionState.handleMouseEnter(.copyButton)
                    NSCursor.pointingHand.push()
                } else {
                    interactionState.handleMouseExit(.copyButton)
                    NSCursor.pop()
                }
            }
            .help("Copy text to clipboard")
            
            Spacer()
            
            // Insert button
            Button {
                withAnimation {
                    TranscriptionResultHandler.shared.handleTranscriptionResult(
                        accumulatedText,
                        recordingStartTime: nil
                    )
                    audioManager.clearAccumulatedText()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Insert")
                        .font(HUDLayout.TextStyle.button)
                        .foregroundColor(.white)
                    
                    Image(systemName: "arrow.down.doc")
                        .font(HUDLayout.TextStyle.buttonIcon)
                        .foregroundColor(.white)
                }
                .padding(HUDLayout.buttonPadding)
                .background(Color.blue)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .scaleEffect(interactionState.scale(for: .copyButton))
            .onHover { hovering in
                if hovering {
                    interactionState.handleMouseEnter(.copyButton)
                    NSCursor.pointingHand.push()
                } else {
                    interactionState.handleMouseExit(.copyButton)
                    NSCursor.pop()
                }
            }
            .help("Insert text at cursor position")
        }
        .padding(.horizontal, HUDLayout.horizontalPadding)
    }
} 