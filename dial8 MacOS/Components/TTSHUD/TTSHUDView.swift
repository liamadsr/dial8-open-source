import SwiftUI

struct TTSHUDView: View {
    @ObservedObject var ttsService = TextToSpeechService.shared
    @StateObject private var animationState = HUDAnimationState()
    @State private var showSpeedMenu = false
    @State private var isHovering = false
    @State private var showingSpeedPopover = false
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Main HUD content
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
                    
                    // Center content area - audio waveform or speed selector
                    if ttsService.state != .idle {
                        TTSAudioWaveformView()
                            .frame(width: 52) // Same width as recording waveform area
                    } else {
                        // Show hint or speed selector
                        VStack(spacing: 2) {
                            if ttsService.currentText != nil {
                                Text("Press Space")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Button(action: {
                                showingSpeedPopover.toggle()
                            }) {
                                Text(ttsService.currentSpeed.displayName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .frame(width: 52)
                        .popover(isPresented: $showingSpeedPopover, arrowEdge: .top) {
                            VStack(spacing: 0) {
                                ForEach(TTSSpeed.allCases, id: \.self) { speed in
                                    Button(action: {
                                        ttsService.currentSpeed = speed
                                        showingSpeedPopover = false
                                    }) {
                                        Text(speed.displayName)
                                            .font(.system(size: 10))
                                            .foregroundColor(ttsService.currentSpeed == speed ? .black : .white)
                                            .frame(width: 60)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(ttsService.currentSpeed == speed ? Color.white : Color.clear)
                                            )
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
            // Apply the same folding animations as STT HUD
            .scaleEffect(x: 1, y: animationState.scaleY, anchor: .center)
            .rotation3DEffect(
                .degrees(animationState.rotationAngle),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                anchor: .center,
                anchorZ: 0,
                perspective: animationState.perspectiveAmount
            )
            .opacity(animationState.opacity)
            .drawingGroup() // Optimize rendering performance
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TTSHUDShouldAnimateIn"))) { _ in
                animationState.animateIn()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TTSHUDShouldAnimateOut"))) { _ in
                animationState.animateOut {
                    // Animation completed
                }
            }
            
            // Circular progress overlay
            if ttsService.state == .playing || ttsService.state == .paused {
                TTSCircularProgressView(progress: ttsService.progress)
                    .frame(width: HUDLayout.expandedWidth, height: HUDLayout.height)
                    .allowsHitTesting(false)  // Don't interfere with buttons
                    .scaleEffect(x: 1, y: animationState.scaleY, anchor: .center)
                    .opacity(animationState.opacity)
            }
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

// Circular progress view that draws around the border
struct TTSCircularProgressView: View {
    let progress: Float
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let cornerRadius = HUDLayout.cornerRadius
            
            // Calculate the perimeter of the rounded rectangle
            let straightSides = 2 * (width + height - 2 * cornerRadius)
            let corners = 2 * .pi * cornerRadius
            let totalPerimeter = straightSides + corners
            
            // Create the progress path
            Path { path in
                let rect = CGRect(x: 0, y: 0, width: width, height: height)
                let progressLength = CGFloat(progress) * totalPerimeter
                var currentLength: CGFloat = 0
                
                // Start from top center
                path.move(to: CGPoint(x: width / 2, y: 0))
                
                // Top edge to right
                let topRightStart = width / 2
                let topRightLength = width / 2 - cornerRadius
                if currentLength + topRightLength <= progressLength {
                    path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
                    currentLength += topRightLength
                } else {
                    let fraction = (progressLength - currentLength) / topRightLength
                    path.addLine(to: CGPoint(x: topRightStart + topRightLength * fraction, y: 0))
                    return
                }
                
                // Top right corner
                if currentLength < progressLength {
                    let cornerLength = cornerRadius * .pi / 2
                    if currentLength + cornerLength <= progressLength {
                        path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                                   radius: cornerRadius,
                                   startAngle: .degrees(-90),
                                   endAngle: .degrees(0),
                                   clockwise: false)
                        currentLength += cornerLength
                    } else {
                        let fraction = (progressLength - currentLength) / cornerLength
                        path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                                   radius: cornerRadius,
                                   startAngle: .degrees(-90),
                                   endAngle: .degrees(-90 + Double(90 * fraction)),
                                   clockwise: false)
                        return
                    }
                }
                
                // Right edge
                if currentLength < progressLength {
                    let rightLength = height - 2 * cornerRadius
                    if currentLength + rightLength <= progressLength {
                        path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
                        currentLength += rightLength
                    } else {
                        let fraction = (progressLength - currentLength) / rightLength
                        path.addLine(to: CGPoint(x: width, y: cornerRadius + rightLength * fraction))
                        return
                    }
                }
                
                // Bottom right corner
                if currentLength < progressLength {
                    let cornerLength = cornerRadius * .pi / 2
                    if currentLength + cornerLength <= progressLength {
                        path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                                   radius: cornerRadius,
                                   startAngle: .degrees(0),
                                   endAngle: .degrees(90),
                                   clockwise: false)
                        currentLength += cornerLength
                    } else {
                        let fraction = (progressLength - currentLength) / cornerLength
                        path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                                   radius: cornerRadius,
                                   startAngle: .degrees(0),
                                   endAngle: .degrees(Double(90 * fraction)),
                                   clockwise: false)
                        return
                    }
                }
                
                // Bottom edge
                if currentLength < progressLength {
                    let bottomLength = width - 2 * cornerRadius
                    if currentLength + bottomLength <= progressLength {
                        path.addLine(to: CGPoint(x: cornerRadius, y: height))
                        currentLength += bottomLength
                    } else {
                        let fraction = (progressLength - currentLength) / bottomLength
                        path.addLine(to: CGPoint(x: width - cornerRadius - bottomLength * fraction, y: height))
                        return
                    }
                }
                
                // Bottom left corner
                if currentLength < progressLength {
                    let cornerLength = cornerRadius * .pi / 2
                    if currentLength + cornerLength <= progressLength {
                        path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                                   radius: cornerRadius,
                                   startAngle: .degrees(90),
                                   endAngle: .degrees(180),
                                   clockwise: false)
                        currentLength += cornerLength
                    } else {
                        let fraction = (progressLength - currentLength) / cornerLength
                        path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                                   radius: cornerRadius,
                                   startAngle: .degrees(90),
                                   endAngle: .degrees(90 + Double(90 * fraction)),
                                   clockwise: false)
                        return
                    }
                }
                
                // Left edge
                if currentLength < progressLength {
                    let leftLength = height - 2 * cornerRadius
                    if currentLength + leftLength <= progressLength {
                        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                        currentLength += leftLength
                    } else {
                        let fraction = (progressLength - currentLength) / leftLength
                        path.addLine(to: CGPoint(x: 0, y: height - cornerRadius - leftLength * fraction))
                        return
                    }
                }
                
                // Top left corner
                if currentLength < progressLength {
                    let cornerLength = cornerRadius * .pi / 2
                    if currentLength + cornerLength <= progressLength {
                        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                                   radius: cornerRadius,
                                   startAngle: .degrees(180),
                                   endAngle: .degrees(270),
                                   clockwise: false)
                        currentLength += cornerLength
                    } else {
                        let fraction = (progressLength - currentLength) / cornerLength
                        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                                   radius: cornerRadius,
                                   startAngle: .degrees(180),
                                   endAngle: .degrees(180 + Double(90 * fraction)),
                                   clockwise: false)
                        return
                    }
                }
                
                // Top edge back to center
                if currentLength < progressLength {
                    let topLeftLength = width / 2 - cornerRadius
                    if currentLength + topLeftLength <= progressLength {
                        path.addLine(to: CGPoint(x: width / 2, y: 0))
                    } else {
                        let fraction = (progressLength - currentLength) / topLeftLength
                        path.addLine(to: CGPoint(x: cornerRadius + topLeftLength * fraction, y: 0))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.6, green: 0.2, blue: 1.0),  // Purple
                        Color(red: 0.3, green: 0.8, blue: 1.0),  // Cyan
                        Color(red: 0.2, green: 1.0, blue: 0.6),  // Green
                        Color(red: 0.9, green: 0.3, blue: 0.8),  // Pink
                        Color(red: 0.6, green: 0.2, blue: 1.0)   // Back to purple
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
            )
            .animation(.linear(duration: 0.1), value: progress)
        }
    }
}