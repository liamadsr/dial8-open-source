import SwiftUI
import Combine
import AVFoundation
import ApplicationServices  // For AXIsProcessTrusted()
import Foundation  // Import Foundation for NotificationCenter
import Cocoa  // For UI components like CursorLoaderIndicator

// Define Recording Modes
enum RecordingMode {
    case transcriptionOnly  // For individual transcription (dictation mode)
}

class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isRecording = false
    @Published var recordingMode: RecordingMode?
    @Published var microphonePermissionGranted: Bool = false
    @Published var accessibilityPermissionGranted: Bool = false
    @Published var useLocalWhisperModel = true
    @Published var whisperModelIsReady: Bool = false
    
    // Flag to prevent didSet during initialization
    private var isInitializing = true
    
    @Published var isStreamingMode: Bool = true {
        didSet {
            let mode = isStreamingMode ? "streaming" : "block"
            print("🎙️ Transcription mode changed to: \(mode)")
            
            // Only save to UserDefaults if not initializing
            if !isInitializing {
                UserDefaults.standard.set(isStreamingMode, forKey: "streamingModeEnabled")
                UserDefaults.standard.synchronize()
                print("💾 Saved transcription mode to UserDefaults: \(mode)")
            } else {
                print("🔄 Skipping UserDefaults save during initialization")
            }
            
            // Update TranscriptionResultHandler's block mode setting
            TranscriptionResultHandler.shared.setBlockMode(!isStreamingMode)
            
            // If switching from block mode to streaming mode and we had accumulated text, insert it
            if isStreamingMode && !audioTranscriptionService.accumulatedText.isEmpty {
                TranscriptionResultHandler.shared.insertAccumulatedText(audioTranscriptionService.accumulatedText)
                audioTranscriptionService.clearAccumulatedText()
            }
            
            // Always maintain streaming functionality for audio processing
            if isRecording {
                audioEngineService.setStreamingState()
                if let engine = audioEngineService.audioEngine {
                    speechDetectionService.startSpeechDetection(with: engine)
                }
            }
        }
    }
    @Published private(set) var isAudioSetupInProgress: Bool = false
    @Published private(set) var isStoppingRecording = false
    @Published private(set) var isSpeechDetected = false
    @Published var recordingStartTime: Date?
    @Published private(set) var currentInputDeviceName: String?
    
    // Dependencies
    @ObservedObject var whisperManager = WhisperManager.shared
    
    // Service layers
    private let audioHUDService: AudioHUDService
    private let audioEngineService = AudioEngineService()
    private let recordingService: AudioRecordingService
    private let audioTranscriptionService = AudioTranscriptionService.shared
    private let speechDetectionService = AudioSpeechDetectionService()
    
    
    // New service layers
    private let audioSessionService = AudioSessionService()
    private let audioPermissionService = AudioPermissionService()
    private let audioHealthService = AudioHealthService()
    private let audioNotificationService = AudioNotificationService()
    private let audioCleanupService: AudioCleanupService
    
    // Extracted services
    private let audioSegmentationService: AudioSegmentationService
    private let audioProcessingQueueService: AudioProcessingQueueService
    private let audioRecoveryService: AudioRecoveryService
    
    
    // UI components
    private var cursorLoaderIndicator: CursorLoaderIndicatorWindowController?
    
    // Other properties
    private var isConfigurationPending = false
    private(set) var isInitialized = false
    
    // Retry tracking for engine startup failures
    private var engineStartupRetryCount = 0
    private let maxEngineStartupRetries = 3
    
    // MARK: - Initialization
    
    init() {
        // Initialize the AudioHUDService
        self.audioHUDService = AudioHUDService()
        
        // Initialize audio engine service first
        
        // Initialize recording service
        self.recordingService = AudioRecordingService(audioEngineService: audioEngineService)
        
        // Initialize cleanup service
        self.audioCleanupService = AudioCleanupService(audioEngineService: audioEngineService)
        
        // Initialize extracted services
        self.audioSegmentationService = AudioSegmentationService(
            recordingService: recordingService,
            audioTranscriptionService: audioTranscriptionService
        )
        
        self.audioProcessingQueueService = AudioProcessingQueueService(
            audioTranscriptionService: audioTranscriptionService,
            whisperManager: WhisperManager.shared
        )
        
        self.audioRecoveryService = AudioRecoveryService(
            audioEngineService: audioEngineService
        )
        
        // Load streaming/block mode setting from UserDefaults (defaults to streaming)
        self.isStreamingMode = UserDefaults.standard.object(forKey: "streamingModeEnabled") as? Bool ?? true
        
        // Initialize TranscriptionResultHandler with the correct block mode setting
        TranscriptionResultHandler.shared.setBlockMode(!self.isStreamingMode)
        
        // Initialization complete - allow UserDefaults saving now
        self.isInitializing = false
        
        let mode = self.isStreamingMode ? "streaming" : "block"
        print("🎙️ Loaded transcription mode from UserDefaults: \(mode)")
        
        isInitialized = true
        
        // Set up speech detection callbacks
        setupSpeechDetectionCallbacks()
        
        // Setup notification service callbacks
        setupNotificationServiceCallbacks()
        
        // Setup service connections
        setupServiceConnections()
        
        // Setup recovery service callbacks
        setupRecoveryCallbacks()
    }
    
    private func setupNotificationServiceCallbacks() {
        // Bind whisper model ready state
        audioNotificationService.$whisperModelIsReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$whisperModelIsReady)
            
        // Bind useLocalWhisperModel
        audioNotificationService.$useLocalWhisperModel
            .receive(on: DispatchQueue.main)
            .assign(to: &$useLocalWhisperModel)
            
        // Setup callbacks
        audioNotificationService.onLanguageChanged = { [weak self] in
            // Language changes are handled in the AudioTranscriptionService
        }
        
        audioNotificationService.onUseLocalWhisperModelChanged = { [weak self] newValue in
            // Model changes are already handled in the notification service itself
        }
    }
    
    private func setupServiceConnections() {
        // Setup AudioSessionService callbacks
        audioSessionService.onSessionInterruption = { [weak self] isBeginning in
            guard let self = self else { return }
            
            if isBeginning {
                if self.isRecording {
                    self.stopRecordingAndSendAudio()
                }
            } else {
                // Reinitialize audio engine with proper state
                self.setupAudioEngine()
            }
        }
        
        // Setup device change callback
        audioSessionService.onDeviceChange = { [weak self] deviceName in
            guard let self = self else { return }
            
            // Update current device name
            DispatchQueue.main.async {
                self.currentInputDeviceName = deviceName
                
                // If recording, show the device change notification
                if self.isRecording {
                    self.audioHUDService.showDeviceChangeNotification(deviceName: deviceName ?? "Unknown Device")
                }
            }
        }
        
        audioSessionService.onRouteChange = { [weak self] in
            guard let self = self, !self.isConfigurationPending else { return }
            
            self.isConfigurationPending = true
            
            // Save current state
            let wasRecording = self.isRecording
            
            // Stop all audio activity first
            self.speechDetectionService.stopSpeechDetection()
            
            // Stop recording but process the audio to preserve it
            self.recordingService.stopRecording(withFinalProcessing: true) { [weak self] finalFileURL in
                guard let self = self else { return }
                
                // If there's audio to preserve, add it to the processing queue
                if let finalFileURL = finalFileURL {
                    print("📝 Preserving audio from before device switch")
                    let timestamp = self.speechDetectionService.getLastSpeechTime() ?? Date()
                    self.audioProcessingQueueService.addToProcessingQueue(
                        audioURL: finalFileURL,
                        timestamp: timestamp
                    )
                }
                
                // Update UI state
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.hideNotchIndicator()
                    
                    // Wait for UI updates to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Stop the engine after UI is updated
                        self.audioEngineService.stopEngine()
                        
                        // Wait for engine to fully stop
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Setup new engine
                            self.setupAudioEngine()
                            
                            // If we were recording, restore state and restart
                            if wasRecording {
                                print("🎙️ Restarting recording after device change...")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    // In block mode, preserve accumulated text
                                    let shouldPreserve = !self.isStreamingMode
                                    self.startRecording(preserveAccumulatedText: shouldPreserve)
                                }
                            }
                            
                            self.isConfigurationPending = false
                            print("✅ Audio engine reconfigured successfully")
                        }
                    }
                }
            }
        }
        
        // Connect AudioPermissionService to AudioManager
        audioPermissionService.$microphonePermissionGranted
            .receive(on: DispatchQueue.main)
            .assign(to: &$microphonePermissionGranted)
            
        audioPermissionService.$accessibilityPermissionGranted
            .receive(on: DispatchQueue.main)
            .assign(to: &$accessibilityPermissionGranted)
        
        // Setup AudioHealthService callbacks
        audioHealthService.checkPermissions = { [weak self] in
            guard let self = self, !self.isRecording else { return }
            self.audioPermissionService.checkPermissions()
        }
        
        audioHealthService.checkAudioEngineState = { [weak self] in
            guard let self = self, self.isRecording else { return }
            
            if self.audioEngineService.engineState == AudioEngineState.inactive {
                print("Audio engine is not running. Reinitializing...")
                self.setupAudioEngine()
                self.audioEngineService.startEngine()
            }
        }
    }
    
    private func setupRecoveryCallbacks() {
        // Configure recovery service callbacks
        audioRecoveryService.onRecoveryStarted = { [weak self] in
            guard let self = self else { return }
            print("Audio recovery process has started...")
            // Optionally show some UI feedback
        }
        
        audioRecoveryService.onRecoverySucceeded = { [weak self] in
            guard let self = self else { return }
            print("Audio recovery was successful!")
            
            // Reinitialize streaming if required
            if self.isRecording {
                self.audioEngineService.setStreamingState()
                if let engine = self.audioEngineService.audioEngine {
                    self.speechDetectionService.startSpeechDetection(with: engine)
                }
            }
        }
        
        audioRecoveryService.onRecoveryFailed = { [weak self] in
            guard let self = self else { return }
            print("Audio recovery failed after all attempts.")
            
            // Handle fatal failure - possibly reset the entire audio stack
            self.resetAudioComponents()
        }
    }
    
    // MARK: - Public API Methods
    
    func startRecording(preserveAccumulatedText: Bool = false) {
        // Cancel any pending cleanup
        audioCleanupService.cancelCleanup()
        
        // Authentication check removed

        guard !isRecording else {
            print("Recording is already in progress.")
            return
        }

        // Ensure we're not in a stopping state (safety check)
        isStoppingRecording = false
        
        let mode = isStreamingMode ? "streaming" : "block"
        print("🎙️ Starting recording in \(mode) mode")
        
        // Reset text insertion state for new recording (unless preserving accumulated text)
        if !preserveAccumulatedText {
            TextInsertionService.shared.resetForNewRecording()
            audioTranscriptionService.clearAccumulatedText()
            TranscriptionResultHandler.shared.clearAccumulatedText()
        } else {
            print("📝 Preserving accumulated text during recording restart")
            // Don't reset TextInsertionService to preserve cursor position
        }
        
        // Set loading state and show HUD immediately
        isAudioSetupInProgress = true
        print("🔄 Audio setup in progress: true")
        
        // Show the HUD immediately with loading state
        DispatchQueue.main.async {
            // Show HUD immediately while audio engine is being set up
            self.isRecording = true
            self.showNotchIndicator()
            print("🎙️ HUD shown with isAudioSetupInProgress: \(self.isAudioSetupInProgress)")
        }
        
        // Get initial device name but don't show notification
        DispatchQueue.global().async { [weak self] in
            let deviceName = self?.audioSessionService.getCurrentInputDeviceName()
            DispatchQueue.main.async {
                self?.currentInputDeviceName = deviceName
            }
        }
        
        // Ensure microphone permission is granted first
        audioPermissionService.requestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }
            if granted {
                DispatchQueue.main.async {
                    // Setup the audio engine with a completion handler
                    self.setupAudioEngineForRecording()
                }
            } else {
                print("Microphone access not granted.")
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.isAudioSetupInProgress = false
                    self.hideNotchIndicator()
                }
            }
        }
    }
    
    func stopRecordingAndSendAudio() {
        // Authentication check removed

        guard isRecording else { return }
        
        print("⏹️ Stopping recording and processing audio...")
        
        // For regular audio recording, proceed with normal workflow
        
        // Set the stopping flag immediately to prevent new speech detection events
        self.isStoppingRecording = true
        
        // For block mode, we need to ensure all audio is processed before fully stopping
        if !isStreamingMode {
            print("📝 Block mode: Ensuring all audio is processed before stopping")
            
            // First, force creation of a new segment to capture any current audio
            // This must happen BEFORE we stop speech detection or mark recording as false
            if let currentSegmentURL = recordingService.startNewAudioSegment() {
                print("📝 Block mode: Adding current segment to processing queue")
                let segmentTimestamp = self.speechDetectionService.getLastSpeechTime() ?? Date()
                audioProcessingQueueService.addToProcessingQueue(
                    audioURL: currentSegmentURL,
                    timestamp: segmentTimestamp
                )
            }
            
            // Give a brief moment for any ongoing audio capture to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.completeRecordingStop()
            }
        } else {
            // For streaming mode, stop immediately
            completeRecordingStop()
        }
    }
    
    private func completeRecordingStop() {
        // Stop audio level monitoring first to prevent spikes
        AudioLevelMonitor.shared.stopMonitoring()
        
        // Update UI state and hide HUD
        DispatchQueue.main.async {
            self.isRecording = false
            self.hideNotchIndicator()
        }
        
        // Stop speech detection
        speechDetectionService.stopSpeechDetection()
        
        // Stop the recording and get the final audio file
        recordingService.stopRecording { [weak self] finalFileURL in
            guard let self = self else { return }
            
            // If there's a final file, add it to the processing queue
            if let finalFileURL = finalFileURL {
                print("📝 Adding final audio segment to processing queue")
                let finalTimestamp = self.speechDetectionService.getLastSpeechTime() ?? Date()
                self.audioProcessingQueueService.addToProcessingQueue(
                    audioURL: finalFileURL,
                    timestamp: finalTimestamp
                )
            }
            
            // For block mode, wait a bit for processing to complete, then flush
            if !self.isStreamingMode {
                // Monitor the queue and flush when it's empty
                self.monitorQueueAndFlushWhenComplete()
            }
            
            // Use segmentation service to handle accumulated text
            self.audioSegmentationService.handleAccumulatedText(
                isStreamingMode: self.isStreamingMode,
                lastSpeechTime: self.speechDetectionService.getLastSpeechTime()
            )
            
            // Clean up audio engine
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔇 Stopping audio engine...")
                self.audioEngineService.stopEngine()
                
                // Reset all state
                self.isStoppingRecording = false
                self.recordingMode = nil
                self.recordingStartTime = nil
                
                // Schedule final cleanup
                self.audioCleanupService.scheduleCleanup()
            }
        }
    }
    
    func stopRecordingAndDiscardAudio() {
        guard isRecording else { return }
        
        print("⏹️ Stopping recording and discarding audio...")
        
        // Set the stopping flag immediately to prevent new speech detection events
        self.isStoppingRecording = true
        
        // Stop audio level monitoring first to prevent spikes
        AudioLevelMonitor.shared.stopMonitoring()
        
        // Stop speech detection
        speechDetectionService.stopSpeechDetection()
        
        // Immediately update UI state and hide HUD
        DispatchQueue.main.async {
            self.isRecording = false
            self.hideNotchIndicator()
        }
        
        // Stop the recording without processing the final audio
        recordingService.stopRecording(withFinalProcessing: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Clean up audio engine
            DispatchQueue.main.async {
                print("🔇 Stopping audio engine...")
                self.audioEngineService.stopEngine()
                
                // Reset all state
                self.isStoppingRecording = false
                self.recordingMode = nil
                self.recordingStartTime = nil
                
                // Schedule final cleanup
                self.audioCleanupService.scheduleCleanup()
            }
        }
    }
    
    func setRecordingMode(_ mode: RecordingMode?) {
        // Authentication check removed

        DispatchQueue.main.async {
            self.recordingMode = mode
            
            // Pass the recording mode to the speech detection service
            self.speechDetectionService.setRecordingMode(mode)
        }
    }
    
    
    /// Toggle between streaming and block mode for transcriptions
    func toggleTranscriptionMode() {
        isStreamingMode.toggle()
        // UserDefaults saving is now handled by didSet observer
    }
    
    /// Set transcription mode explicitly
    func setTranscriptionMode(_ streaming: Bool) {
        isStreamingMode = streaming
        // UserDefaults saving is now handled by didSet observer
    }
    
    func resetAudioComponents() {
        print("Resetting audio components")
        audioEngineService.stopEngine()
        setupAudioEngine()
        isRecording = false
        hideNotchIndicator()
    }
    
    func requestMicrophonePermission() {
        audioPermissionService.requestMicrophonePermission()
    }
    
    func clearAccumulatedText() {
        audioTranscriptionService.clearAccumulatedText()
    }
    
    func waitUntilReady() async {
        // Wait for up to 5 seconds for the audio engine to be ready
        for _ in 0..<50 {
            if isInitialized && !isConfigurationPending {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngineForRecording() {
        print("AudioManager: Setting up audio engine for recording")
        
        // Setup the engine
        setupAudioEngine()
        
        // Add a minimum delay to ensure loading animation is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // Check engine state and wait for it to be ready
            self?.checkEngineReadyAndStartRecording()
        }
    }
    
    private func checkEngineReadyAndStartRecording(attempts: Int = 0) {
        // Check if engine is ready
        if audioEngineService.engineState != .inactive && audioEngineService.audioEngine != nil {
            print("AudioManager: Audio engine is ready, starting recording components")
            
            // Engine is ready, start recording components
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Set up audio engine for streaming
                self.audioEngineService.setStreamingState()
                
                // Start audio level monitoring
                AudioLevelMonitor.shared.startMonitoring()
                
                // Begin actual recording
                self.recordingService.beginRecording()
                
                // Sync recording start time
                self.recordingStartTime = self.recordingService.recordingStartTime
                
                // Audio setup is now complete
                self.isAudioSetupInProgress = false
                print("🔄 Audio setup complete - transitioning to recording")
                
                // Play ready sound with a small delay to avoid overlap with activation sound
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    HUDSoundEffects.shared.playReadySound()
                }
                
                // Reset retry count on successful start
                self.engineStartupRetryCount = 0
                
                // Start speech detection
                if let engine = self.audioEngineService.audioEngine {
                    self.speechDetectionService.startSpeechDetection(with: engine)
                }
            }
        } else if attempts < 10 { // Max 1 second wait (10 * 100ms)
            // Engine not ready yet, check again in 100ms
            print("AudioManager: Engine not ready yet, checking again... (attempt \(attempts + 1))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.checkEngineReadyAndStartRecording(attempts: attempts + 1)
            }
        } else {
            // Timeout - engine failed to start
            print("AudioManager: Engine failed to start after timeout")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isRecording = false
                self.isAudioSetupInProgress = false
                
                // Show retry notification
                self.showEngineFailedNotification()
            }
        }
    }
    
    private func setupAudioEngine() {
        print("AudioManager: Setting up audio engine - START")
        
        // Prevent multiple simultaneous setups
        guard !isConfigurationPending else {
            print("Setup already in progress, skipping...")
            return
        }
        
        isConfigurationPending = true
        
        // Stop any existing engine first
        audioEngineService.stopEngine()
        
        // Initialize a new audio engine
        self.audioEngineService.setupAudioEngine()
        
        // Set up audio buffer callback for level monitoring
        self.audioEngineService.onAudioBuffer = { [weak self] buffer in
            AudioLevelMonitor.shared.processAudioBuffer(buffer)
        }
        
        // Start the engine
        if self.audioEngineService.startEngine() {
            print("AudioManager: Audio engine started successfully")
        } else {
            print("AudioManager: Failed to start audio engine")
            // Use recovery service instead of direct recovery
            self.audioRecoveryService.attemptRecovery()
        }
        
        self.isConfigurationPending = false
    }
    
    // MARK: - Speech Detection
    
    private func setupSpeechDetectionCallbacks() {
        // Bind the speech detection service state to our own
        speechDetectionService.$isSpeechDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeechDetected)
            
        speechDetectionService.onSpeechDetected = { [weak self] in
            guard let self = self else { return }
            
            // Skip speech detection updates if we're in the process of stopping
            if self.isStoppingRecording {
                print("🚫 Speech detected while stopping recording - ignoring")
                return
            }
        }
        
        speechDetectionService.onSilenceDetected = { [weak self] in
            guard let self = self else { return }
            
            // Use segmentation service to handle silence detection
            self.audioSegmentationService.handleSilenceDetected(
                isRecording: self.isRecording,
                isStoppingRecording: self.isStoppingRecording,
                lastSpeechTime: self.speechDetectionService.getLastSpeechTime(),
                isStreamingMode: self.isStreamingMode
            )
        }
    }
    
    // MARK: - UI Management
    
    private func showNotchIndicator() {
        audioHUDService.showHUD(audioManager: self)
    }

    private func hideNotchIndicator() {
        audioHUDService.hideHUD()
    }
    
    private func showEngineFailedNotification() {
        // Automatically retry up to maxEngineStartupRetries times
        engineStartupRetryCount += 1
        
        if engineStartupRetryCount < maxEngineStartupRetries {
            print("AudioManager: Engine startup failed. Retrying... (attempt \(engineStartupRetryCount + 1) of \(maxEngineStartupRetries))")
            
            // Wait a bit before retrying to give the system time to recover
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                // Retry the recording process
                self.startRecording(preserveAccumulatedText: !self.isStreamingMode)
            }
        } else {
            // Max retries reached, give up
            print("AudioManager: Engine startup failed after \(maxEngineStartupRetries) attempts. Giving up.")
            engineStartupRetryCount = 0 // Reset for next time
            hideNotchIndicator()
        }
    }
    
    
    private func showCursorLoader() {
        print("showCursorLoader called")
        DispatchQueue.main.async {
            if self.cursorLoaderIndicator == nil {
                let mouseLocation = NSEvent.mouseLocation
                self.cursorLoaderIndicator = CursorLoaderIndicatorWindowController(at: mouseLocation)
                self.cursorLoaderIndicator?.show()
            }
        }
    }

    private func hideCursorLoader() {
        print("hideCursorLoader called")
        DispatchQueue.main.async {
            self.cursorLoaderIndicator?.hide()
            self.cursorLoaderIndicator = nil
            print("All cursor loader indicators hidden and released")
        }
    }
    
    // MARK: - Queue Monitoring for Block Mode
    
    private func monitorQueueAndFlushWhenComplete() {
        // Check queue status every 100ms
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Check if the processing queue is empty
            if self.audioProcessingQueueService.queueLength == 0 {
                print("📝 Block mode: Processing queue is empty, flushing accumulated text")
                
                // Stop the timer
                timer.invalidate()
                
                // Flush the accumulated text
                DispatchQueue.main.async {
                    TranscriptionResultHandler.shared.flushAccumulatedText()
                }
            } else {
                print("📝 Block mode: Waiting for queue to process \(self.audioProcessingQueueService.queueLength) items")
            }
        }
    }
    
    // MARK: - Deinitialization
    
    deinit {
        // Ensure cleanup of HUD resources through the service
        audioHUDService.cleanup()
        
        // Clean up audio health service
        audioHealthService.cleanup()
        
        // Cancel cleanup timer
        audioCleanupService.cancelCleanup()
        
        // Stop audio engine
        audioEngineService.stopEngine()
        
        // Cancel any recovery in progress
        audioRecoveryService.cancelRecovery()
    }
}
