import Foundation

class AudioCleanupService {
    // MARK: - Properties
    
    private var cleanupTimer: DispatchWorkItem?
    private let cleanupDelay: TimeInterval
    private weak var audioEngineService: AudioEngineService?
    
    // MARK: - Initialization
    
    init(audioEngineService: AudioEngineService, cleanupDelay: TimeInterval = 30) {
        self.audioEngineService = audioEngineService
        self.cleanupDelay = cleanupDelay
    }
    
    // MARK: - Public Methods
    
    /// Schedules a cleanup operation after a delay
    func scheduleCleanup() {
        // Cancel any existing timer first
        cleanupTimer?.cancel()
        
        print("Scheduling audio engine cleanup in \(cleanupDelay) seconds")
        
        // Create a new work item for cleanup
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let audioEngineService = self.audioEngineService else { return }
            
            // Only perform cleanup if engine is in warm standby
            if audioEngineService.engineState == AudioEngineState.warmStandby {
                self.performFullCleanup()
            }
        }
        
        // Store and schedule the timer
        cleanupTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + cleanupDelay, execute: workItem)
    }
    
    /// Cancels any scheduled cleanup operation
    func cancelCleanup() {
        cleanupTimer?.cancel()
        cleanupTimer = nil
    }
    
    /// Performs immediate cleanup of audio resources
    func performFullCleanup() {
        audioEngineService?.stopEngine()
        print("Audio engine cleaned up after idle period")
    }
    
    // MARK: - Deinitialization
    
    deinit {
        // Ensure timer is canceled when service is deallocated
        cancelCleanup()
    }
} 
