import Foundation
import AVFoundation
import Accelerate

/// Monitors audio levels and provides smoothed amplitude data for visualization
class AudioLevelMonitor: ObservableObject {
    static let shared = AudioLevelMonitor()
    
    // Published properties for UI binding
    @Published var currentLevel: Float = 0.0
    @Published var smoothedLevel: Float = 0.0
    @Published var isActive: Bool = false
    
    // Configuration
    private let noiseFloor: Float = 0.005 // Balanced threshold
    private let smoothingFactor: Float = 0.0 // No smoothing - not used anymore
    private let amplificationFactor: Float = 5.0 // Moderate amplification for controlled height
    private let updateInterval: TimeInterval = 0.008 // ~125Hz for ultra-smooth motion
    
    // Processing state
    private var lastUpdateTime: Date = Date()
    private var levelHistory: [Float] = []
    private let historySize = 1 // No averaging, direct response
    private var warmupTime: Date?
    private let warmupDuration: TimeInterval = 0.8 // 800ms warmup to avoid initial spikes
    
    private init() {}
    
    /// Process audio buffer and extract level information
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
    
    /// Start monitoring audio levels
    func startMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.isActive = true
            self?.levelHistory.removeAll()
            self?.smoothedLevel = 0
            self?.currentLevel = 0
            self?.warmupTime = Date()  // Start warmup period
        }
    }
    
    /// Stop monitoring audio levels
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
    
    /// Reset the monitor
    func reset() {
        stopMonitoring()
    }
}