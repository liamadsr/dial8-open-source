import Foundation
import AVFoundation
import Combine

class AudioRecoveryService: ObservableObject {
    // Dependencies
    private let audioEngineService: AudioEngineService
    
    // State
    @Published private(set) var isRecoveryInProgress = false
    private let retryDelays = [0.5, 1.0, 2.0] // Delays in seconds between recovery attempts
    
    // Callbacks
    var onRecoveryStarted: (() -> Void)?
    var onRecoverySucceeded: (() -> Void)?
    var onRecoveryFailed: (() -> Void)?
    
    init(audioEngineService: AudioEngineService) {
        self.audioEngineService = audioEngineService
    }
    
    /// Attempts to recover the audio engine with multiple retry attempts
    func attemptRecovery() {
        guard !isRecoveryInProgress else {
            print("Recovery already in progress, ignoring duplicate request")
            return
        }
        
        print("🔄 Starting audio engine recovery process...")
        isRecoveryInProgress = true
        onRecoveryStarted?()
        
        attemptRecoveryWithIndex(0)
    }
    
    /// Stops any ongoing recovery attempts
    func cancelRecovery() {
        isRecoveryInProgress = false
        print("🛑 Audio engine recovery cancelled")
    }
    
    // MARK: - Private Methods
    
    private func attemptRecoveryWithIndex(_ attemptIndex: Int) {
        guard isRecoveryInProgress else {
            print("Recovery was cancelled, aborting further attempts")
            return
        }
        
        guard attemptIndex < retryDelays.count else {
            print("❌ Audio engine recovery failed after all attempts")
            isRecoveryInProgress = false
            onRecoveryFailed?()
            return
        }
        
        let delay = retryDelays[attemptIndex]
        print("Recovery attempt \(attemptIndex + 1) will execute in \(delay) seconds")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isRecoveryInProgress else { return }
            
            print("Executing recovery attempt \(attemptIndex + 1)...")
            
            // Stop the engine first
            self.audioEngineService.stopEngine()
            
            // Set up a new engine
            self.audioEngineService.setupAudioEngine()
            
            // Try to start the engine
            if self.audioEngineService.startEngine() {
                print("✅ Audio engine recovered successfully on attempt \(attemptIndex + 1)")
                self.isRecoveryInProgress = false
                self.onRecoverySucceeded?()
            } else {
                print("❌ Recovery attempt \(attemptIndex + 1) failed, trying next attempt")
                self.attemptRecoveryWithIndex(attemptIndex + 1)
            }
        }
    }
} 
