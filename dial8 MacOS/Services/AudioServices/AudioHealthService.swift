import Foundation
import AVFoundation

class AudioHealthService {
    // Properties
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 300 // 5 minutes
    
    // Callback closures
    var onHealthCheck: (() -> Void)?
    var checkAudioEngineState: (() -> Void)?
    var checkPermissions: (() -> Void)?
    
    init() {
        startHealthCheckTimer()
    }
    
    // MARK: - Health Check Timer
    
    func startHealthCheckTimer() {
        // Invalidate any existing timer first
        healthCheckTimer?.invalidate()
        
        // Create a new timer
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }
    
    func stopHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    // MARK: - Health Checks
    
    func performHealthCheck() {
        DispatchQueue.main.async { [weak self] in
            self?.onHealthCheck?()
            self?.checkPermissions?()
            self?.checkAudioEngineState?()
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopHealthCheckTimer()
    }
    
    deinit {
        cleanup()
    }
} 
