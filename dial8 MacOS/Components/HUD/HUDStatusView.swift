import SwiftUI

/// Status view components for the HUD
struct HUDStatusView {
    /// Authentication status view
    struct AuthView: View {
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            HStack(spacing: HUDLayout.spacing) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Model Settings")
                        .font(HUDLayout.TextStyle.title)
                        .foregroundColor(.primary)
                    Text("Sign in to begin.")
                        .font(HUDLayout.TextStyle.subtitle)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
    
    /// Usage limit status view
    struct UsageView: View {
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            HStack(spacing: HUDLayout.spacing) {
                Image("StatusBarIcon")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Model Settings")
                        .font(HUDLayout.TextStyle.title)
                        .foregroundColor(.primary)
                    Text("Unlock Pro features")
                        .font(HUDLayout.TextStyle.subtitle)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
    
    /// Recording status view
    struct RecordingView: View {
        @ObservedObject var audioManager: AudioManager
        @State private var initialRecordingMode: RecordingMode?
        @ObservedObject var animationState: HUDAnimationState
        @ObservedObject var interactionState: HUDInteractionState
        @Environment(\.colorScheme) private var colorScheme
        var isHovering: Bool = false
        var isRecordingLocked: Bool = false
        
        var body: some View {
            HStack(spacing: 0) {
                if isRecordingLocked && audioManager.isRecording && !audioManager.isAudioSetupInProgress {
                    // Expanded view when recording is locked
                    HStack(spacing: 0) {
                        // Trash button on the left
                        Button(action: {
                            audioManager.stopRecordingAndDiscardAudio()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 20, height: 20)
                                
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.red)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        // Waveform in the center
                        AudioWaveformView()
                            .frame(maxWidth: .infinity)
                        
                        Spacer()
                        
                        // X button on the right to process recording
                        Button(action: {
                            audioManager.stopRecordingAndSendAudio()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 20, height: 20)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale))
                } else if isHovering && audioManager.isRecording && !audioManager.isAudioSetupInProgress && !isRecordingLocked {
                    // Show just trash icon when hovering in push-to-talk mode
                    Button(action: {
                        audioManager.stopRecordingAndDiscardAudio()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: "trash.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.red)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 52)
                    .transition(.opacity)
                } else if audioManager.isAudioSetupInProgress {
                    SetupAnimationView()
                        .frame(width: 52)  // Fits the ultra-compact HUD
                        .transition(.opacity)
                        .onAppear {
                            print("🔄 HUD: Showing setup animation")
                        }
                } else if audioManager.isRecording {
                    AudioWaveformView()
                        .frame(width: 52)  // Fits the ultra-compact HUD
                        .transition(.opacity)
                        .onAppear {
                            print("🎙️ HUD: Showing waveform")
                        }
                } else {
                    // Show setup animation as fallback during initial state
                    SetupAnimationView()
                        .frame(width: 52)
                        .transition(.opacity)
                        .onAppear {
                            print("⏳ HUD: Showing setup animation (fallback)")
                        }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)  // Reduced for smaller height
            .onAppear {
                initialRecordingMode = audioManager.recordingMode
                print("📊 HUD Status - Setup: \(audioManager.isAudioSetupInProgress), Recording: \(audioManager.isRecording)")
            }
            .onChange(of: audioManager.isAudioSetupInProgress) { newValue in
                print("📊 HUD Status Changed - Setup: \(newValue), Recording: \(audioManager.isRecording)")
            }
        }
    }
}

/// Setup animation with bouncing dots
struct SetupAnimationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animatingIndex = 0
    
    let dotCount = 8  // Match the waveform bar count
    let timer = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()  // Faster animation
    
    var body: some View {
        HStack(spacing: 2) {  // Match waveform spacing
            ForEach(0..<dotCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)  // Always use white (light mode style)
                    .frame(width: 3, height: animatingIndex == index ? 14 : 2)  // Smaller heights
                    .animation(.easeInOut(duration: 0.3), value: animatingIndex)
            }
        }
        .onReceive(timer) { _ in
            animatingIndex = (animatingIndex + 1) % dotCount
        }
    }
}


/// Native-style toggle for consistent macOS appearance
struct NativeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                configuration.isOn.toggle()
            }
        }) {
            ZStack {
                // Track with native styling
                Capsule()
                    .fill(configuration.isOn ? 
                          Color.accentColor : 
                          Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                Color(NSColor.separatorColor).opacity(0.3),
                                lineWidth: 0.5
                            )
                    )
                    .frame(width: 42, height: 24)
                
                // Thumb with native appearance
                Circle()
                    .fill(Color(NSColor.controlColor))
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
                    .frame(width: 20, height: 20)
                    .offset(x: configuration.isOn ? 9 : -9)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
            }
        }
        .buttonStyle(.plain)
    }
} 
