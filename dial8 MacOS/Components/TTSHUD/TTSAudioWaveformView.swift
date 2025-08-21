import SwiftUI
import AVFoundation
import Accelerate

/// Audio waveform visualization specifically for TTS
struct TTSAudioWaveformView: View {
    @ObservedObject private var audioMonitor = TTSAudioMonitor.shared
    @State private var animatedBars: [CGFloat] = Array(repeating: 2, count: 8)
    @State private var appearTime: Date?
    @State private var updateCount = 0
    
    let barCount = 8  // Reduced for narrower HUD
    let maxBarHeight: CGFloat = 18  // Further reduced for ultra-compact HUD
    let minBarHeight: CGFloat = 2   // Tiny minimum for compact size
    
    var body: some View {
        HStack(spacing: 2) {  // Reduced spacing for more bars
            ForEach(0..<barCount, id: \.self) { index in
                TTSWaveformBar(
                    height: animatedBars[index],
                    maxHeight: maxBarHeight,
                    minHeight: minBarHeight
                )
            }
        }
        .onReceive(audioMonitor.$smoothedLevel) { level in
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
            print("🎵 TTSAudioWaveformView appeared - Monitor active: \(audioMonitor.isActive)")
        }
        .onDisappear {
            print("🎵 TTSAudioWaveformView disappeared")
            appearTime = nil
            updateCount = 0
        }
    }
    
    private func updateBars(with level: Float) {
        // No animation wrapper for instant updates - exactly like STT
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

/// Individual bar in the waveform - exactly like STT
struct TTSWaveformBar: View {
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

/// Dedicated audio monitor for TTS that doesn't interfere with STT
class TTSAudioMonitor: ObservableObject {
    static let shared = TTSAudioMonitor()
    
    @Published var currentLevel: Float = 0.0
    @Published var smoothedLevel: Float = 0.0
    @Published var isActive: Bool = false
    
    // Configuration - matching STT timing but adjusted levels for TTS
    private let noiseFloor: Float = 0.005 // Balanced threshold
    private let smoothingFactor: Float = 0.0 // No smoothing - not used anymore
    private let amplificationFactor: Float = 1.5 // Further reduced amplification for TTS
    private let updateInterval: TimeInterval = 0.008 // ~125Hz for ultra-smooth motion
    
    // Processing state
    private var lastUpdateTime: Date = Date()
    private var levelHistory: [Float] = []
    private let historySize = 1 // No averaging, direct response
    private var warmupTime: Date?
    private let warmupDuration: TimeInterval = 0.8 // 800ms warmup to avoid initial spikes
    private var bufferCount = 0
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isActive,
              let channelData = buffer.floatChannelData else { return }
        
        // Check if we're still in warmup period
        if let warmup = warmupTime {
            let elapsed = Date().timeIntervalSince(warmup)
            if elapsed < warmupDuration {
                // During warmup, return minimal levels to avoid spikes
                DispatchQueue.main.async { [weak self] in
                    self?.currentLevel = 0
                    self?.smoothedLevel = 0
                }
                return
            } else if elapsed < warmupDuration + 0.1 {
                // First buffer after warmup
                print("🎤 Warmup complete, processing audio (elapsed: \(elapsed)s)")
            }
        }
        
        // Calculate RMS (Root Mean Square) level
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        
        var rms: Float = 0
        vDSP_rmsqv(channelDataValue, 1, &rms, vDSP_Length(frameLength))
        
        // Apply noise floor threshold
        let thresholdedLevel = max(0, rms - noiseFloor) / (1 - noiseFloor)
        
        // Apply square root scaling for more natural response
        let scaledLevel = sqrt(thresholdedLevel) * amplificationFactor
        
        // Apply a power curve to make quiet sounds more visible but prevent over-accumulation
        let curvedLevel = pow(scaledLevel, 0.8)
        
        // Clamp to 0-1 range
        let normalizedLevel = min(1.0, curvedLevel)
        
        // Update level history for averaging
        levelHistory.append(normalizedLevel)
        if levelHistory.count > historySize {
            levelHistory.removeFirst()
        }
        
        // Calculate averaged level
        let averageLevel = levelHistory.reduce(0, +) / Float(levelHistory.count)
        
        // Update published values on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update current level directly
            self.currentLevel = averageLevel
            
            // Direct assignment for instant response (no accumulation)
            self.smoothedLevel = averageLevel
        }
    }
    
    func startMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.isActive = true
            self?.levelHistory.removeAll()
            self?.smoothedLevel = 0
            self?.currentLevel = 0
            self?.warmupTime = Date()  // Start warmup period
        }
    }
    
    func stopMonitoring() {
        // Set isActive to false immediately to stop processing
        isActive = false
        
        DispatchQueue.main.async { [weak self] in
            self?.smoothedLevel = 0
            self?.currentLevel = 0
            self?.levelHistory.removeAll()
            self?.warmupTime = nil
        }
    }
    
    func reset() {
        stopMonitoring()
    }
}