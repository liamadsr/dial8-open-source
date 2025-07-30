import Foundation
import AVFoundation
import Cocoa
import CoreAudio

class AudioSessionService {
    // Callback closures
    var onSessionInterruption: ((Bool) -> Void)?
    var onRouteChange: (() -> Void)?
    var onDeviceChange: ((String?) -> Void)?  // New callback with device name
    
    init() {
        setupAudioSessionNotifications()
    }
    
    // MARK: - Notification Setup
    
    func setupAudioSessionNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif

        // Add observer for audio route changes (device changes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: NSNotification.Name.AVAudioEngineConfigurationChange,
            object: nil
        )
    }
    
    // MARK: - Notification Handlers
    
    @objc func handleAudioSessionInterruption(notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .began {
            print("Audio session interruption began")
            onSessionInterruption?(true)
        } else if type == .ended {
            print("Audio session interruption ended")
            onSessionInterruption?(false)
        }
        #endif
    }

    @objc func handleAudioRouteChange(_ notification: Notification) {
        print("🎧 Audio route change detected")
        
        // Get the new device name
        let deviceName = getCurrentInputDeviceName()
        print("🎤 New input device: \(deviceName ?? "Unknown")")
        
        // Call both callbacks
        onDeviceChange?(deviceName)
        onRouteChange?()
    }
    
    // MARK: - Device Name Detection
    
    func getCurrentInputDeviceName() -> String? {
        #if os(macOS)
        var deviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        // Get the default input device ID
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        
        guard status == noErr else {
            print("Failed to get default input device ID: \(status)")
            return nil
        }
        
        // Get the device name
        propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
        propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
        
        var deviceName: CFString?
        dataSize = UInt32(MemoryLayout<CFString?>.size)
        
        let nameStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )
        
        guard nameStatus == noErr, let name = deviceName as String? else {
            print("Failed to get device name: \(nameStatus)")
            return nil
        }
        
        return name
        #else
        // iOS implementation would use AVAudioSession
        return AVAudioSession.sharedInstance().currentRoute.inputs.first?.portName
        #endif
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 
