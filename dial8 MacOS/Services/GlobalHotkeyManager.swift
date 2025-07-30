import Foundation
import AVFoundation
import Cocoa
import SwiftUI
import Combine
import ApplicationServices
import Carbon

// Removed HotkeyBehavior enum - now using separate hotkeys for push-to-talk and toggle modes

class GlobalHotkeyManager: ObservableObject {
    // MARK: - Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    @Published var isRecording = false
    
    // Track if text overlay is currently showing - Now handled by hudState computed property
    
    @ObservedObject var windowManager: WindowManager
    private let statusBarController: StatusBarController
    @ObservedObject var audioManager: AudioManager

    private var previousFlags: CGEventFlags?
    private var currentKeyCombo: KeyCombo?
    private var pressedKeys: Set<Int> = []
    var recordingMode: RecordingMode?
    
    // Removed hotkeyBehavior - now using separate hotkeys for push-to-talk and toggle modes
    
    // Track key state for push-to-talk
    private var isHotkeyPressed = false
    private var pushToTalkKeyCombo: KeyCombo?
    private var isRecordingLocked = false  // When space is pressed, recording continues without holding Option


    // Add the eventTapCallback property
    private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
        let manager: GlobalHotkeyManager = Unmanaged.fromOpaque(userInfo).takeUnretainedValue()
        return manager.handleEvent(proxy: proxy, type: type, event: event)
    }

    // Add state monitoring
    private var isMonitoringEventTap = false
    private var monitorTimer: Timer?

    // Define an enum for HUD state
    private enum HUDState {
        case hidden           // HUD is completely hidden
        case showingOverlay   // Text overlay is showing
        case showingTranscription // Transcription HUD is showing
        case transitioning    // In the middle of showing/hiding
    }
    
    // Single source of truth for HUD state
    private var hudState: HUDState = .hidden {
        didSet {
            logHUDStateTransition(from: oldValue, to: hudState)
            
            // Cancel transition timeout if we've left transitioning state
            if oldValue == .transitioning && hudState != .transitioning {
                transitionTimeoutTimer?.invalidate()
                transitionTimeoutTimer = nil
            }
        }
    }
    
    
    private var isTextOverlayShowing: Bool {
        get {
            return hudState == .showingOverlay
        }
        set {
            if newValue && (hudState == .hidden || hudState == .transitioning) {
                hudState = .showingOverlay
            } else if !newValue && hudState == .showingOverlay {
                hudState = .transitioning // Will be reset to .hidden when animation completes
                startTransitionTimeout()
            }
        }
    }
    
    // Track when the Fn key was last pressed to prevent rapid toggling
    private let fnKeyDebounceTime: TimeInterval = 0.05 // 50ms debounce (was 300ms)
    
    // Tracking for Control+Option combination for transcription toggle
    private var lastTranscriptionToggleTime: Date?
    private let transcriptionToggleDebounceTime: TimeInterval = 0.3 // 300ms debounce (was 500ms)
    
    
    // Add a timeout mechanism for transitioning state
    private var transitionTimeoutTimer: Timer?
    private let transitionTimeout: TimeInterval = 0.5 // 500ms timeout for transitions

    // MARK: - Initialization

    init(windowManager: WindowManager,
         statusBarController: StatusBarController,
         audioManager: AudioManager) {

        self.windowManager = windowManager
        self.statusBarController = statusBarController
        self.audioManager = audioManager

        // Initialize previousFlags with empty flags
        self.previousFlags = CGEventFlags(rawValue: 0)

        // Set up the event tap for capturing global hotkeys
        setupEventTap()

        // Start monitoring the event tap
        startEventTapMonitoring()

        // Observe changes in recording status
        self.audioManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        }

    deinit {
        stopEventTapMonitoring()
        cleanupEventTap()
        NotificationCenter.default.removeObserver(self)
        
        // Clean up timer
        transitionTimeoutTimer?.invalidate()
        transitionTimeoutTimer = nil
    }


    // MARK: - Event Tap and Hotkey Handling

    private func startEventTapMonitoring() {
        guard !isMonitoringEventTap else { return }
        
        isMonitoringEventTap = true
        
        // Check event tap status every 2 seconds
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkEventTapStatus()
        }
    }
    
    private func stopEventTapMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoringEventTap = false
    }
    
    private func checkEventTapStatus() {
        if !isEventTapWorking() {
            resetEventTap()
        }
    }

    private func setupEventTap() {
        // Clean up any existing event tap first
        cleanupEventTap()
        
        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        
        // Reset state
        self.previousFlags = CGEventFlags(rawValue: 0)
        self.pressedKeys.removeAll()
        self.currentKeyCombo = nil
        
    }
    
    private func cleanupEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            CFMachPortInvalidate(eventTap)
        }
        
        self.eventTap = nil
        self.runLoopSource = nil
    }
    
    func resetEventTap() {
        setupEventTap()
        
        // Verify the reset was successful
        if isEventTapWorking() {
        } else {
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let hotkeyManager = HotkeyManager.shared
        let flags = event.flags
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        
        // Flag to track if we directly handled specific keys
        var directlyHandledKey = false
        
        // Handle ESC key press to dismiss text overlay
        if type == .keyDown && keyCode == 53 {
            if hudState == .showingOverlay {
                hudState = .transitioning
                startTransitionTimeout()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .dismissSelectedTextOverlay, object: nil)
                }
                return Unmanaged.passRetained(event)
            } else if hudState == .showingTranscription {
                stopRecordingAndSendAudio()
                return Unmanaged.passRetained(event)
            }
        }
        
        // Handle flag changes (modifier keys)
        if type == .flagsChanged {
            let flagsRaw: UInt64 = flags.rawValue
            
            
            // Now check for configured hotkeys 
            let lastFlags = previousFlags ?? CGEventFlags(rawValue: 0)
            let newlyPressedFlags = flags.subtracting(lastFlags)
            
            if !newlyPressedFlags.isEmpty || (flags.rawValue != 0 && hudState == .hidden) {
                // Check for matching hotkey and ensure it's enabled
                // We also allow checking even when no new flags are pressed if we're in hidden state
                // This helps recover from scenarios where key release events were missed
                if let config = hotkeyManager.findConfigurationForKeyCombo(modifiers: flags.rawValue, keyCode: -1),
                   config.isEnabled {
                    
                    // Handle based on action type
                    if config.action == .pushToTalk {
                        // Check if we're in a locked recording session
                        if isRecording && isRecordingLocked {
                            // Option pressed while locked - stop recording
                            print("🛑 Push-to-talk: Option pressed while locked, stopping recording")
                            stopRecordingAndSendAudio()
                            isRecordingLocked = false
                            isHotkeyPressed = false
                            pushToTalkKeyCombo = nil
                        } else if !isHotkeyPressed {
                            // Normal push-to-talk start
                            isHotkeyPressed = true
                            pushToTalkKeyCombo = KeyCombo(keyCode: -1, modifiers: flags.rawValue)
                            
                            if !isRecording {
                                print("🎙️ Push-to-talk: Key pressed, starting recording")
                                recordingMode = .transcriptionOnly
                                audioManager.setRecordingMode(recordingMode)
                                audioManager.startRecording()
                            }
                        }
                        directlyHandledKey = true
                        previousFlags = flags
                        return Unmanaged.passRetained(event)
                    } else {
                        // Toggle mode or other actions
                        handleHotkeyAction(config.action)
                        directlyHandledKey = true
                        previousFlags = flags
                        return Unmanaged.passRetained(event)
                    }
                }
            }
            
            // The hotkey configuration system above handles all key combinations now
            
            // Check for push-to-talk key release by comparing modifiers
            if isHotkeyPressed && pushToTalkKeyCombo != nil {
                // Check if the tracked modifier combination is no longer pressed
                if let combo = pushToTalkKeyCombo {
                    // For modifier-only hotkeys
                    if combo.keyCode == -1 {
                        // Check if any of the required modifiers are missing in current flags
                        let requiredModifiers = CGEventFlags(rawValue: combo.modifiers)
                        let currentHasAllModifiers = flags.contains(requiredModifiers)
                        
                        if !currentHasAllModifiers {
                            // Key was released
                            isHotkeyPressed = false
                            
                            if isRecording && !isRecordingLocked {
                                // Only stop if recording is not locked
                                print("🎙️ Push-to-talk: Option released, stopping recording")
                                stopRecordingAndSendAudio()
                                pushToTalkKeyCombo = nil
                            } else if isRecording && isRecordingLocked {
                                print("🔒 Push-to-talk: Option released but recording is locked, continuing...")
                            }
                        }
                    }
                }
            }
            
            // Handle key release events (when flags go from non-zero to zero)
            // This helps ensure we're ready for the next hotkey press
            if lastFlags.rawValue != 0 && flags.rawValue == 0 {
                
                // If we're in a transitioning state for too long, force reset to hidden
                if hudState == .transitioning {
                    hudState = .hidden
                }
                
                // Reset previous flags to ensure clean state for next hotkey detection
                previousFlags = flags
                
                // If we just stopped transcription, give time for other events and then completely reset flags
                if !isRecording && lastTranscriptionToggleTime != nil {
                    let now = Date()
                    if let lastStop = lastTranscriptionToggleTime, now.timeIntervalSince(lastStop) < 1.0 {
                        // Schedule a more complete reset after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                            guard let self = self else { return }
                            // Reset flags to ensure clean state
                            self.previousFlags = CGEventFlags(rawValue: 0)
                        }
                    }
                }
            }
            
            // Save the current flags for next comparison
            previousFlags = flags
        }
        
        // Handle hotkey learning mode
        if hotkeyManager.isRecordingHotkey {
            switch type {
            case .flagsChanged:
                previousFlags = flags
                
                // Record modifier-only shortcuts
                if pressedKeys.isEmpty {
                    let keyCombo = KeyCombo(keyCode: -1, modifiers: flags.rawValue)
                    currentKeyCombo = keyCombo
                    hotkeyManager.recordNewKeyCombo(keyCombo)
                }
                
            case .keyDown:
                if !pressedKeys.contains(keyCode) {
                    pressedKeys.insert(keyCode)
                    updateCurrentKeyCombo(flags: flags)
                }
                
            case .keyUp:
                pressedKeys.remove(keyCode)
                if pressedKeys.isEmpty {
                    // Finalize the key combination when all keys are released
                    if let combo = currentKeyCombo {
                        hotkeyManager.recordNewKeyCombo(combo)
                    }
                    currentKeyCombo = nil
                } else {
                    // Update the combo if there are still keys pressed
                    updateCurrentKeyCombo(flags: flags)
                }
                
            default:
                break
            }
            return nil
        }
        
        // Skip regular hotkey handling if we've already directly handled keys
        if directlyHandledKey {
            return Unmanaged.passRetained(event)
        }
        
        // Handle space bar during push-to-talk recording
        if isRecording && keyCode == 49 { // 49 is space bar
            // Check if Command is pressed - if so, let the system handle it (for Spotlight, etc.)
            if flags.contains(.maskCommand) {
                return Unmanaged.passRetained(event)
            }
            
            if type == .keyDown && !isRecordingLocked {
                // Space pressed while recording - lock the recording
                isRecordingLocked = true
                print("🔒 Push-to-talk: Recording locked - press Option to stop")
                // Post notification to update UI if needed
                NotificationCenter.default.post(name: Notification.Name("RecordingLockedStateChanged"), object: nil, userInfo: ["isLocked": true])
            }
            return nil // Consume the space bar event (only when Command is not pressed)
        }
        
        // Regular hotkey handling for key press events
        if type == .keyDown {
            if let config = hotkeyManager.findConfigurationForKeyCombo(modifiers: flags.rawValue, keyCode: keyCode),
               config.isEnabled {
                
                // Handle based on action type
                if config.action == .pushToTalk {
                    // Check if we're in a locked recording session
                    if isRecording && isRecordingLocked {
                        // Hotkey pressed while locked - stop recording
                        print("🛑 Push-to-talk: Hotkey pressed while locked, stopping recording")
                        stopRecordingAndSendAudio()
                        isRecordingLocked = false
                        isHotkeyPressed = false
                        pushToTalkKeyCombo = nil
                    } else if !isHotkeyPressed {
                        // Normal push-to-talk start
                        isHotkeyPressed = true
                        pushToTalkKeyCombo = KeyCombo(keyCode: keyCode, modifiers: flags.rawValue)
                        
                        if !isRecording {
                            print("🎙️ Push-to-talk: Key pressed, starting recording")
                            recordingMode = .transcriptionOnly
                            audioManager.setRecordingMode(recordingMode)
                            audioManager.startRecording()
                        }
                    }
                } else {
                    // Toggle mode or other actions
                    handleHotkeyAction(config.action)
                }
            }
        }
        
        // Handle key up events for push-to-talk
        if type == .keyUp && isHotkeyPressed {
            // Check if this is the key we're tracking
            if let combo = pushToTalkKeyCombo, combo.keyCode == keyCode {
                isHotkeyPressed = false
                
                if isRecording && !isRecordingLocked {
                    print("🎙️ Push-to-talk: Key released, stopping recording")
                    stopRecordingAndSendAudio()
                    pushToTalkKeyCombo = nil
                } else if isRecording && isRecordingLocked {
                    print("🔒 Push-to-talk: Key released but recording is locked, continuing...")
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func handleHotkeyAction(_ action: HotkeyAction) {
        print("🎯 Handling hotkey action: \(action)")
        
        switch action {
        case .toggleMode:
            // Toggle mode - press to start/stop recording
            if isRecording {
                print("🎙️ Toggle Mode: Already recording, stopping recording")
                stopRecordingAndSendAudio()
                return
            }
            
            // If any HUD is showing, first try to dismiss it
            if hudState != .hidden && hudState != .transitioning {
                print("🎯 HUD is showing when toggle hotkey pressed, dismissing it")
                
                switch hudState {
                case .showingOverlay:
                    hudState = .transitioning
                    startTransitionTimeout()
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .dismissSelectedTextOverlay, object: nil)
                    }
                    return
                case .showingTranscription:
                    // If in transcription mode, stop it
                    if isRecording {
                        stopRecordingAndSendAudio()
                    }
                    return
                default:
                    break
                }
                return
            }
            
            // Start recording in toggle mode
            print("🎙️ Toggle Mode: Starting recording")
            recordingMode = .transcriptionOnly
            audioManager.setRecordingMode(recordingMode)
            audioManager.startRecording()
            
        case .pushToTalk:
            // Push-to-talk mode - handled in the keyDown/keyUp events
            print("🎙️ Push-to-talk action detected")
            // The actual push-to-talk behavior is handled in the event handling code
            
        case .transcribe:
            // Legacy support - map to toggle mode behavior
            print("⚠️ Legacy transcribe action detected, using toggle mode behavior")
            handleHotkeyAction(.toggleMode)
        }
    }


    private func updateCurrentKeyCombo(flags: CGEventFlags) {
        // Filter out modifier key codes
        let nonModifierKeys = pressedKeys.filter { keyCode in
            !Set([55, 56, 59, 58, 63]).contains(keyCode)
        }
        
        let keyCombo = KeyCombo(
            keyCode: nonModifierKeys.first ?? -1,
            modifiers: flags.rawValue,
            additionalKeyCodes: Array(nonModifierKeys.dropFirst())
        )
        
        currentKeyCombo = keyCombo
    }

    private func stopRecordingAndSendAudio() {
        guard isRecording else { return }
        
        print("🎙️ Stopping transcription")
        isRecording = false
        audioManager.stopRecordingAndSendAudio()
        
        // Reset recording mode
        recordingMode = nil
        audioManager.recordingMode = nil
        
        // Reset lock state
        if isRecordingLocked {
            isRecordingLocked = false
            NotificationCenter.default.post(name: Notification.Name("RecordingLockedStateChanged"), object: nil, userInfo: ["isLocked": false])
        }
        
        // Update hudState if we're in transcription mode
        if hudState == .showingTranscription {
            print("🎙️ Updating HUD state after stopping transcription")
            
            // Skip transitioning state - go directly to hidden
            // This makes the system immediately ready for the next hotkey press
            print("🎙️ Directly setting state to hidden to avoid transition delays")
            hudState = .hidden
            
            // Ensure flags are reset so we can detect the next modifier key press
            previousFlags = CGEventFlags(rawValue: 0)
            
            // Cancel any transition timer that might be active
            transitionTimeoutTimer?.invalidate()
            transitionTimeoutTimer = nil
        }
        
        // Let user know transcription is deactivated
        print("🎙️ Transcription mode deactivated and system ready for next hotkey")
    }

    private func isEventTapWorking() -> Bool {
        guard let eventTap = eventTap else {
            print("❌ Event tap is nil")
            return false
        }
        
        let isEnabled = CGEvent.tapIsEnabled(tap: eventTap)
        return isEnabled
    }

    // Start transcription (used for Control+Option toggle)
    private func startTranscription() {
        // Only start if not already recording
        if isRecording {
            print("🎙️ Already recording, not starting transcription")
            return
        }
        
        // If any HUD is showing, hide it first
        if hudState != .hidden && hudState != .transitioning {
            print("🎙️ HUD is showing, dismissing before transcription")
            
            if hudState == .showingOverlay {
                hudState = .transitioning
                startTransitionTimeout()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .dismissSelectedTextOverlay, object: nil)
                }
            }
            
            // Wait briefly to allow the dismiss animation to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.startRecordingForTranscription()
            }
        } else {
            // Start recording immediately
            startRecordingForTranscription()
        }
    }
    
    // Start recording for transcription (helper method)
    private func startRecordingForTranscription() {
        print("🎙️ Starting transcription")
        recordingMode = .transcriptionOnly
        audioManager.setRecordingMode(recordingMode)
        audioManager.startRecording()
        
        // Update state to reflect transcription mode
        // If we're in transitioning state, wait briefly before updating
        if hudState == .transitioning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                if self.hudState == .transitioning || self.hudState == .hidden {
                    print("🎙️ Setting HUD state to showingTranscription after transition delay")
                    self.hudState = .showingTranscription
                }
            }
        } else {
            hudState = .showingTranscription
        }
        
        // Let user know transcription is active
        print("🎙️ Transcription mode activated - press Control+Option again to stop recording")
    }

    // These methods are no longer used with the toggle approach
    private func handleLongPressFnKey() {
        // This method is no longer used since we're using Control+Option toggle for transcription
    }
    
    private func startPushToTalkTimer() {
        // This method is no longer used since we're using Control+Option toggle for transcription
    }

    // Add a new method to handle transition timeout
    private func startTransitionTimeout() {
        // Cancel any existing timeout timer
        transitionTimeoutTimer?.invalidate()
        
        // Create a new timeout timer
        transitionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: transitionTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            print("⚠️ HUD transition timeout occurred. Current state: \(self.hudState)")
            
            // If we're still in transitioning state after timeout, force reset to hidden
            if self.hudState == .transitioning {
                print("🔄 Forcing HUD state reset to hidden due to timeout")
                self.hudState = .hidden
            }
        }
    }

    // Diagnostic methods to help debug HUD state issues
    private func logHUDStateTransition(from oldState: HUDState, to newState: HUDState) {
        // Log invalid state transitions
        let invalidTransitions: [(HUDState, HUDState)] = [
            (.showingOverlay, .showingTranscription)
        ]
        
        if invalidTransitions.contains(where: { $0.0 == oldState && $0.1 == newState }) {
            print("⚠️ INVALID HUD STATE TRANSITION: \(oldState) -> \(newState)")
            logBacktrace()
        }
        
        // Check for appropriate transitioning states
        if newState != .transitioning && oldState != .transitioning && newState != .hidden && oldState != .hidden {
            print("⚠️ MISSING TRANSITIONING STATE: \(oldState) -> \(newState)")
            logBacktrace()
        }
    }
    
    private func logBacktrace() {
        // Get stack trace programmatically
        let symbols = Thread.callStackSymbols
        print("📋 STACK TRACE:")
        for (index, symbol) in symbols.enumerated() {
            if index > 1 && index < 10 { // Skip top frames and limit depth
                print("   \(index): \(symbol)")
            }
        }
    }

    // Toggle transcription on/off with Control+Option
    private func toggleTranscription() {
        if isRecording {
            // If already recording, stop it
            print("🎙️ Control+Option pressed - Toggling transcription OFF")
            stopRecordingAndSendAudio()
        } else {
            // If not recording, start it
            print("🎙️ Control+Option pressed - Toggling transcription ON")
            startTranscription()
        }
    }
    
}

extension Notification.Name {
    // These notifications are already defined in OnboardingView.swift
    static let audioStateChanged = Notification.Name("audioStateChanged")
    static let showSelectedTextOverlay = Notification.Name("showSelectedTextOverlay")
    static let dismissSelectedTextOverlay = Notification.Name("dismissSelectedTextOverlay")
    static let hudDidMove = Notification.Name("hudDidMove")
    // Add notifications for transcription state
    static let transcriptionStarted = Notification.Name("transcriptionStarted")
    static let transcriptionStopped = Notification.Name("transcriptionStopped")
    // This notification is already defined in OnboardingView.swift
    // static let startFnKeyDetection = Notification.Name("startFnKeyDetection")
}
