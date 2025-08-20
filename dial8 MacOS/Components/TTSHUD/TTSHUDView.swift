import SwiftUI

struct TTSHUDView: View {
    @ObservedObject var ttsService = TextToSpeechService.shared
    @State private var showSpeedMenu = false
    @State private var isHovering = false
    @State private var showingSpeedPopover = false
    var onDismiss: () -> Void
    
    var body: some View {
        RoundedRectangle(cornerRadius: HUDLayout.cornerRadius)
            .fill(Color.black)
            .overlay(
                // Thin gray outline
                RoundedRectangle(cornerRadius: HUDLayout.cornerRadius)
                    .stroke(Color(white: 0.6, opacity: 0.7), lineWidth: 1.2)
            )
            .overlay(
                HStack(spacing: 0) {
                    // Play/Pause button on the left with extra padding
                    Button(action: {
                        ttsService.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: playPauseIcon)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(playPauseTooltip)
                    .padding(.leading, 6)  // Extra padding from left edge
                    
                    Spacer()
                    
                    // Center content area - progress bars or speed selector
                    if ttsService.state != .idle {
                        TTSProgressBars()
                            .frame(width: 52) // Same width as recording waveform area
                    } else {
                        // Show speed selector when not playing
                        Button(action: {
                            showingSpeedPopover.toggle()
                        }) {
                            Text(ttsService.currentSpeed.displayName)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 52)
                        .popover(isPresented: $showingSpeedPopover, arrowEdge: .top) {
                            VStack(spacing: 0) {
                                ForEach(TTSSpeed.allCases, id: \.self) { speed in
                                    Button(action: {
                                        ttsService.currentSpeed = speed
                                        showingSpeedPopover = false
                                    }) {
                                        HStack {
                                            Text(speed.displayName)
                                                .font(.system(size: 10))
                                            if ttsService.currentSpeed == speed {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8))
                                            }
                                        }
                                        .foregroundColor(ttsService.currentSpeed == speed ? .white : .gray)
                                        .frame(width: 60)
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical, 4)
                            .background(Color.black)
                            .cornerRadius(6)
                        }
                    }
                    
                    Spacer()
                    
                    // Stop button on the right with extra padding
                    Button(action: {
                        ttsService.stop()
                        onDismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Stop")
                    .padding(.trailing, 6)  // Extra padding from right edge
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            )
            .frame(width: HUDLayout.expandedWidth, height: HUDLayout.height)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
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
    
    private var playPauseTooltip: String {
        switch ttsService.state {
        case .playing:
            return "Pause"
        case .paused:
            return "Resume"
        case .idle, .stopped:
            return "Play"
        }
    }
}

// Progress bars visualization similar to audio waveform
struct TTSProgressBars: View {
    @ObservedObject var ttsService = TextToSpeechService.shared
    @State private var animatingBar = 0
    
    let barCount = 8
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.2), value: animatingBar)
            }
        }
        .onReceive(timer) { _ in
            if ttsService.state == .playing {
                animatingBar = (animatingBar + 1) % barCount
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if ttsService.state == .playing {
            // Animate bars based on progress
            let progressIndex = Int(ttsService.progress * Float(barCount))
            if index <= progressIndex {
                return animatingBar == index ? 14 : 8
            } else {
                return 2
            }
        } else if ttsService.state == .paused {
            // Show static progress when paused
            let progressIndex = Int(ttsService.progress * Float(barCount))
            return index <= progressIndex ? 8 : 2
        } else {
            return 2
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let progressIndex = Int(ttsService.progress * Float(barCount))
        if index <= progressIndex {
            return Color.white
        } else {
            return Color.white.opacity(0.3)
        }
    }
}