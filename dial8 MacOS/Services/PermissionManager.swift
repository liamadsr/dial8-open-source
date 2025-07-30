/// PermissionManager is a singleton service that handles all system-level permission requests and checks.
/// It provides a centralized way to manage:
/// - Microphone permissions for audio capture
/// - Accessibility permissions for system-wide features
/// - System preferences navigation for permission settings
///
/// Usage:
/// ```swift
/// // Check microphone permission
/// PermissionManager.shared.checkMicrophonePermission { granted in
///     if granted {
///         // Handle granted permission
///     }
/// }
///
/// // Check accessibility permission
/// if PermissionManager.shared.checkAccessibilityPermission() {
///     // Handle granted permission
/// }
/// ```

import AVFoundation
import ApplicationServices
import Speech

#if os(macOS)
import AppKit
#endif

class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    // MARK: - Microphone Permission
    
    func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let granted = permissionStatus == .authorized
        DispatchQueue.main.async {
            completion(granted)
        }
    }
    
    func checkMicrophonePermissionSync() -> Bool {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return permissionStatus == .authorized
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        print("🎤 Requesting microphone permission...")
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎤 Current microphone status: \(permissionStatus.rawValue)")
        
        switch permissionStatus {
        case .notDetermined:
            print("🎤 Showing system microphone permission prompt...")
            // This should trigger the system prompt
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("🎤 User responded to microphone prompt: \(granted)")
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            print("🎤 Microphone permission previously denied, opening System Settings...")
            DispatchQueue.main.async {
                self.openSystemPreferencesPrivacyMicrophone()
                completion(false)
            }
        case .authorized:
            print("🎤 Microphone already authorized")
            DispatchQueue.main.async {
                completion(true)
            }
        @unknown default:
            print("🎤 Unknown microphone permission status")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    // MARK: - Speech Recognition Permission
    
    func checkSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        DispatchQueue.main.async {
            completion(status == .authorized)
        }
    }
    
    func checkSpeechRecognitionPermissionSync() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    func requestSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        print("🗣️ Requesting speech recognition permission...")
        let status = SFSpeechRecognizer.authorizationStatus()
        print("🗣️ Current speech recognition status: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("🗣️ Showing system speech recognition prompt...")
            SFSpeechRecognizer.requestAuthorization { authStatus in
                print("🗣️ User responded to speech recognition prompt: \(authStatus.rawValue)")
                DispatchQueue.main.async {
                    let granted = authStatus == .authorized
                    if !granted {
                        print("🗣️ Speech recognition not granted, opening System Settings...")
                        self.openSystemPreferencesPrivacySpeech()
                    }
                    completion(granted)
                }
            }
        case .denied, .restricted:
            print("🗣️ Speech recognition previously denied, opening System Settings...")
            DispatchQueue.main.async {
                self.openSystemPreferencesPrivacySpeech()
                completion(false)
            }
        case .authorized:
            print("🗣️ Speech recognition already authorized")
            DispatchQueue.main.async {
                completion(true)
            }
        @unknown default:
            print("🗣️ Unknown speech recognition status")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    // MARK: - Accessibility Permission
    
    func checkAccessibilityPermission() -> Bool {
        print("🔑 PERMISSION: Checking accessibility permission")
        #if os(macOS)
        let result = AXIsProcessTrusted()
        print("🔑 PERMISSION: Accessibility permission status: \(result)")
        return result
        #else
        return true
        #endif
    }
    
    func requestAccessibilityPermissionWithPrompt(completion: @escaping (Bool) -> Void) {
        print("🔑 Requesting accessibility permission...")
        
        #if os(macOS)
        let currentStatus = AXIsProcessTrusted()
        print("🔑 Current accessibility status: \(currentStatus)")
        
        // First, trigger the system prompt
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let promptShown = AXIsProcessTrustedWithOptions(options)
        print("🔑 Accessibility prompt shown: \(promptShown)")
        
        // Give the user a moment to respond to the prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let newStatus = AXIsProcessTrusted()
            print("🔑 New accessibility status: \(newStatus)")
            
            if !newStatus {
                print("🔑 Permission not granted, opening System Settings...")
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            completion(newStatus)
        }
        #else
        DispatchQueue.main.async {
            completion(true)
        }
        #endif
    }
    
    // MARK: - System Preferences Helpers
    
    func openSystemPreferencesPrivacyMicrophone() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
    
    func openSystemPreferencesPrivacySpeech() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
