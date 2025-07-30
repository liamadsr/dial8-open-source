import SwiftUI

/// Audio waveform visualization for the HUD
struct AudioWaveformView: View {
    @ObservedObject var levelMonitor = AudioLevelMonitor.shared
    @State private var animatedBars: [CGFloat] = Array(repeating: 2, count: 8)
    @State private var appearTime: Date?
    @State private var updateCount = 0
    
    let barCount = 8  // Reduced for narrower HUD
    let maxBarHeight: CGFloat = 18  // Further reduced for ultra-compact HUD
    let minBarHeight: CGFloat = 2   // Tiny minimum for compact size
    
    var body: some View {
        HStack(spacing: 2) {  // Reduced spacing for more bars
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    height: animatedBars[index],
                    maxHeight: maxBarHeight,
                    minHeight: minBarHeight
                )
            }
        }
        .onReceive(levelMonitor.$smoothedLevel) { level in
            // Wait a moment after appearing before processing levels
            if let appear = appearTime {
                let elapsed = Date().timeIntervalSince(appear)
                if elapsed > 0.2 && updateCount > 3 {  // Wait 200ms AND skip first 3 updates
                    updateBars(with: level)
                } else {
                    // Keep bars at minimum during initial period
                    animatedBars = Array(repeating: minBarHeight, count: barCount)
                    updateCount += 1
                }
            }
        }
        .onAppear {
            // Initialize bars and set appear time
            animatedBars = Array(repeating: minBarHeight, count: barCount)
            appearTime = Date()
            updateCount = 0
            print("🎵 AudioWaveformView appeared - Level monitor active: \(levelMonitor.isActive)")
        }
        .onDisappear {
            print("🎵 AudioWaveformView disappeared")
            appearTime = nil
            updateCount = 0
        }
    }
    
    private func updateBars(with level: Float) {
        // No animation wrapper for instant updates
        for i in 0..<barCount {
            // Create wave pattern that distributes energy more evenly
            let phase = Double(i) / Double(barCount) * Double.pi * 2
            // Use a different phase offset that starts lower for the first bar
            let waveOffset = sin(phase + Double.pi * 0.75 + Double(level) * 3) * 0.12 + 0.88
            let barLevel = CGFloat(level) * CGFloat(waveOffset)
            
            // Apply additional dampening to the first bar
            let dampening: CGFloat = (i == 0) ? 0.85 : 1.0
            animatedBars[i] = minBarHeight + (maxBarHeight - minBarHeight) * barLevel * dampening
        }
    }
}

/// Individual bar in the waveform
struct WaveformBar: View {
    let height: CGFloat
    let maxHeight: CGFloat
    let minHeight: CGFloat
    
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)  // Always use white (light mode style)
            .frame(width: 3, height: height)  // Thinner bars for more granularity
    }
}

/// Horizontal waveform style (alternative visualization)
struct HorizontalWaveformView: View {
    @ObservedObject var levelMonitor = AudioLevelMonitor.shared
    @State private var wavePhase: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2
                
                path.move(to: CGPoint(x: 0, y: midY))
                
                // Create smooth wave based on audio level
                for x in stride(from: 0, through: width, by: 2) {
                    let relativeX = Double(x / width)
                    let waveHeight = CGFloat(levelMonitor.smoothedLevel) * (height * 0.4)
                    
                    // Create undulating wave
                    let y = midY + CGFloat(sin(relativeX * Double.pi * 4 + wavePhase) * Double(waveHeight))
                    
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.6),
                        Color.blue,
                        Color.blue.opacity(0.6)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
        }
        .frame(height: 30)
        .onAppear {
            // Animate wave phase for smooth motion
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }
}