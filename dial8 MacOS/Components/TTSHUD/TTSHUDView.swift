import SwiftUI

struct TTSHUDView: View {
    @ObservedObject var ttsService = TextToSpeechService.shared
    @State private var showSpeedMenu = false
    @State private var isHovering = false
    var onDismiss: () -> Void
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black)
            .overlay(
                // Thin gray outline
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(white: 0.6, opacity: 0.7), lineWidth: 1.2)
            )
            .overlay(
                VStack(spacing: 4) {
                    // Progress bar at top
                    if ttsService.state != .idle {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 2)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * CGFloat(ttsService.progress), height: 2)
                                    .animation(.linear(duration: 0.1), value: ttsService.progress)
                            }
                        }
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                    }
                    
                    // Controls
                    HStack(spacing: 10) {
                        // Play/Pause button
                        Button(action: {
                            ttsService.togglePlayPause()
                        }) {
                            Image(systemName: playPauseIcon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Speed selector
                        Menu {
                            ForEach(TTSSpeed.allCases, id: \.self) { speed in
                                Button(action: {
                                    ttsService.currentSpeed = speed
                                }) {
                                    HStack {
                                        Text(speed.displayName)
                                        if ttsService.currentSpeed == speed {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(ttsService.currentSpeed.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.15)))
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .fixedSize()
                        
                        Spacer()
                        
                        // Stop button
                        Button(action: {
                            ttsService.stop()
                            onDismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.red.opacity(0.3)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, ttsService.state != .idle ? 4 : 8)
                }
            )
            .frame(width: 160, height: 44)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .onHover { hovering in
                isHovering = hovering
            }
    }
    
    private var playPauseIcon: String {
        switch ttsService.state {
        case .playing:
            return "pause.fill"
        case .paused, .idle, .stopped:
            return "play.fill"
        }
    }
}