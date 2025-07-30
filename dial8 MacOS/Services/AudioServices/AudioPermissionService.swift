import Foundation
import AVFoundation
import Combine

class AudioPermissionService: ObservableObject {
    // Published properties for permission states
    @Published var microphonePermissionGranted: Bool = false
    @Published var accessibilityPermissionGranted: Bool = false
    
    init() {
        // Initial check of permissions
        checkPermissions()
    }
    
    // MARK: - Permission Checking
    
    func checkPermissions() {
        // Use PermissionManager for microphone permission
        self.microphonePermissionGranted = PermissionManager.shared.checkMicrophonePermissionSync()

        // Use PermissionManager for accessibility permission
        self.accessibilityPermissionGranted = PermissionManager.shared.checkAccessibilityPermission()
    }
    
    // MARK: - Permission Requesting
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void = { _ in }) {
        PermissionManager.shared.requestMicrophonePermission { granted in
            print("Microphone permission granted: \(granted)")
            DispatchQueue.main.async {
                self.microphonePermissionGranted = granted
                completion(granted)
            }
        }
    }
} 
