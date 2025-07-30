import AVFoundation
import Foundation
import Combine

enum AudioEngineState {
    case inactive      // Fully stopped
    case warmStandby   // Engine running but not recording
    case streaming     // Active recording with streaming functionality
}

class AudioEngineService: ObservableObject {
    private(set) var audioEngine: AVAudioEngine?
    @Published private(set) var engineState: AudioEngineState = .inactive
    
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    private var isConfigurationPending = false
    
    // Added converterNode for sample rate conversion
    private var converterNode: AVAudioMixerNode?
    
    private var isRecoveryInProgress = false
    private var currentFormat: AVAudioFormat?
    private var deviceChangeObserver: NSObjectProtocol?
    private var configChangeObserver: NSObjectProtocol?
    
    private var audioConverter: AVAudioConverter?
    
    init() {
        setupNotifications()
        // Don't automatically setup the audio engine
        // It will be setup when needed
    }
    
    private func setupNotifications() {
        // Remove any existing observers
        if let observer = deviceChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Observe system device changes
        deviceChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main) { [weak self] _ in
                print("AudioEngineService: Device configuration change detected")
                self?.handleDeviceChange()
        }
        
        // Observe audio engine configuration changes
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main) { [weak self] _ in
                print("AudioEngineService: Engine configuration change detected")
                self?.handleConfigurationChange()
        }
    }
    
    private func handleDeviceChange() {
        print("AudioEngineService: Device change detected")
        // Use a longer delay for device changes to allow the system to stabilize
        gracefulReconfiguration(delay: 0.3)
    }
    
    private func handleConfigurationChange() {
        print("AudioEngineService: Configuration change detected")
        gracefulReconfiguration(delay: 0.1)
    }
    
    private func gracefulReconfiguration(delay: TimeInterval) {
        // Only reconfigure if not already in progress
        guard !isConfigurationPending && !isRecoveryInProgress else {
            print("AudioEngineService: Reconfiguration already in progress")
            return
        }
        
        isConfigurationPending = true
        engineState = .inactive
        
        // Stop engine gracefully
        if let converter = converterNode {
            converter.removeTap(onBus: 0)
            converterNode = nil
        }
        
        audioEngine?.stop()
        audioEngine = nil
        currentFormat = nil
        
        // Wait before reconfiguring
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            // Setup new engine
            self.setupAudioEngine()
            
            // Wait for engine to be ready before restoring state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Restore previous state if needed
                if self.engineState == .warmStandby {
                    self.isConfigurationPending = false
                }
            }
        }
    }
    
    func setupAudioEngine() {
        print("AudioEngineService: Setting up audio engine - START")
        
        // Clean up existing engine if any
        stopEngine()
        
        // Create new engine
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            print("AudioEngineService: Failed to create audio engine")
            return
        }
        
        // Get the native input format
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.inputFormat(forBus: 0)
        print("AudioEngineService: Native input format: \(nativeFormat)")
        
        // Create and configure converter node
        converterNode = AVAudioMixerNode()
        guard let converterNode = converterNode else {
            print("AudioEngineService: Failed to create converter node")
            return
        }
        
        // Set converter node volume to 0 to prevent monitoring
        converterNode.volume = 0
        
        // Add converter node to engine
        audioEngine.attach(converterNode)
        
        // Connect input to converter using native format
        audioEngine.connect(inputNode, to: converterNode, format: nativeFormat)
        
        // Create a fixed format for speech recognition (16kHz, mono, float32)
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 16000,
                                         channels: 1,
                                         interleaved: false)
        
        guard let format = desiredFormat else {
            print("AudioEngineService: Failed to create audio format")
            return
        }
        
        // Store format for future reference
        currentFormat = format
        
        // Create audio converter once
        audioConverter = AVAudioConverter(from: nativeFormat, to: format)
        
        guard let audioConverter = audioConverter else {
            print("AudioEngineService: Failed to create audio converter")
            return
        }
        
        // Install tap on converter node with native format
        let bufferSize: AVAudioFrameCount = 1024
        converterNode.installTap(onBus: 0, bufferSize: bufferSize, format: nativeFormat) { [weak self] buffer, _ in
            guard let self = self, !self.isConfigurationPending else { return }
            
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                                  frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate))!
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            audioConverter.convert(to: convertedBuffer,
                                 error: &error,
                                 withInputFrom: inputBlock)
            
            if error == nil {
                self.onAudioBuffer?(convertedBuffer)
            } else {
                print("AudioEngineService: Buffer conversion error: \(error?.localizedDescription ?? "unknown")")
            }
        }
        
        // Prepare engine
        audioEngine.prepare()
        
        // Try to start the engine immediately
        do {
            try audioEngine.start()
            engineState = .warmStandby
            print("AudioEngineService: Engine initialized and started successfully")
        } catch {
            print("AudioEngineService: Failed to start engine during setup: \(error)")
            engineState = .inactive
            if !isRecoveryInProgress {
                attemptRecovery()
            }
        }
    }
    
    func startEngine() -> Bool {
        guard let audioEngine = audioEngine else {
            print("AudioEngineService: No audio engine available")
            return false
        }
        
        do {
            try audioEngine.start()
            engineState = .warmStandby
            print("AudioEngineService: Engine started successfully")
            return true
        } catch {
            print("AudioEngineService: Failed to start engine: \(error)")
            engineState = .inactive
            if !isRecoveryInProgress {
                attemptRecovery()
            }
            return false
        }
    }
    
    func stopEngine() {
        print("AudioEngineService: Stopping engine...")
        
        // Set state to prevent new operations
        isConfigurationPending = true
        engineState = .inactive
        
        // Remove tap from converter node if available
        if let converter = converterNode {
            converter.removeTap(onBus: 0)
            converterNode = nil
            print("AudioEngineService: Removed converter tap")
        }
        
        // Stop engine if running
        if let engine = audioEngine, engine.isRunning {
            // Remove any remaining taps from input node
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            print("AudioEngineService: Engine stopped")
        }
        
        // Clear all references
        audioEngine = nil
        currentFormat = nil
        audioConverter = nil
        
        // Reset configuration state
        isConfigurationPending = false
        print("AudioEngineService: Engine cleanup complete")
    }
    
    func setStreamingState() {
        // Prevent setting streaming state if configuration is pending
        guard !isConfigurationPending else {
            print("AudioEngineService: Cannot set streaming state while configuration is pending")
            return
        }
        
        // If already in streaming state, just return
        if engineState == .streaming {
            print("AudioEngineService: Already in streaming state")
            return
        }
        
        // If engine is not available or not running, set it up
        if audioEngine == nil || !(audioEngine?.isRunning ?? false) {
            print("AudioEngineService: Setting up new engine for streaming")
            setupAudioEngine()
            
            // Wait for engine to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                
                if let engine = self.audioEngine, engine.isRunning {
                    self.engineState = .streaming
                    print("AudioEngineService: Engine ready and set to streaming state")
                } else {
                    print("AudioEngineService: Failed to prepare engine for streaming")
                }
            }
            return
        }
        
        // If we have a running engine, just update the state
        engineState = .streaming
        print("AudioEngineService: Updated to streaming state")
    }
    
    func reconfigureEngine() {
        print("AudioEngineService: Reconfiguring engine")
        isConfigurationPending = true
        
        // Stop current engine
        stopEngine()
        
        // Wait before setting up new engine
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.setupAudioEngine()
            _ = self.startEngine()
            self.isConfigurationPending = false
        }
    }
    
    private func attemptRecovery() {
        isRecoveryInProgress = true
        
        // Try to recover up to 3 times with increasing delays
        let delays = [0.5, 1.0, 2.0]
        
        func attempt(index: Int) {
            guard index < delays.count else {
                print("AudioEngineService: Recovery failed after all attempts")
                isRecoveryInProgress = false
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delays[index]) { [weak self] in
                guard let self = self else { return }
                
                print("AudioEngineService: Recovery attempt \(index + 1)")
                self.setupAudioEngine()
                
                if self.startEngine() {
                    print("AudioEngineService: Recovery successful")
                    self.isRecoveryInProgress = false
                } else {
                    attempt(index: index + 1)
                }
            }
        }
        
        attempt(index: 0)
    }
    
    deinit {
        // Remove observers
        if let observer = deviceChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopEngine()
    }
} 
