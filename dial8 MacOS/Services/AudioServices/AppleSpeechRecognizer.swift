import Foundation
import Speech
import AVFoundation

class AppleSpeechRecognizer: NSObject, ObservableObject {
    static let shared = AppleSpeechRecognizer()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Remove audioEngine property as we'll use the shared one
    private var audioEngine: AVAudioEngine?
    
    @Published var isListening = false
    @Published var isSpeechDetected = false
    
    // Callback for when speech is detected
    var onSpeechDetected: (() -> Void)?
    // Callback for when silence is detected
    var onSilenceDetected: (() -> Void)?
    
    private var silenceTimer: Timer?
    // Different silence thresholds based on recording mode
    private var defaultSilenceThreshold: TimeInterval = 0.8  // Reduced for faster transcription
    private var meetingSilenceThreshold: TimeInterval = 1.5  // Keep longer for meeting transcription
    // Current silence threshold (default to regular transcription)
    private var silenceThreshold: TimeInterval = 0.8
    // Track current recording mode
    private var currentRecordingMode: RecordingMode?
    
    private var isConfigurationPending = false
    
    private var inputTap: AVAudioNodeTapBlock?
    private var currentInputNode: AVAudioInputNode?
    private var hasTapInstalled = false
    
    private var isTransitioning = false
    private var pendingEngine: AVAudioEngine?
    private let transitionQueue = DispatchQueue(label: "com.dial8.speechrecognizer.transition")
    
    override private init() {
        super.init()
        // Only request authorization, don't start listening
        requestAuthorization()
        
        // Listen for pause detection threshold changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseDetectionThresholdChanged(_:)),
            name: NSNotification.Name("PauseDetectionThresholdChanged"),
            object: nil
        )
        
        // Load initial pause detection threshold
        let storedThreshold = UserDefaults.standard.double(forKey: "pauseDetectionThreshold")
        if storedThreshold > 0 {
            silenceThreshold = storedThreshold
            meetingSilenceThreshold = storedThreshold
        }
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition authorization denied")
                case .restricted:
                    print("Speech recognition restricted on this device")
                case .notDetermined:
                    print("Speech recognition not yet authorized")
                @unknown default:
                    print("Unknown authorization status")
                }
            }
        }
    }
    
    // Set recording mode to adjust silence threshold
    func setRecordingMode(_ mode: RecordingMode?) {
        currentRecordingMode = mode
        
        // Use the user-configured threshold instead of hardcoded values
        let storedThreshold = UserDefaults.standard.double(forKey: "pauseDetectionThreshold")
        if storedThreshold > 0 {
            silenceThreshold = storedThreshold
        } else {
            // Fallback to default if not set
            silenceThreshold = meetingSilenceThreshold
        }
        
        print("🎙️ Set transcription silence threshold: \(silenceThreshold) seconds")
        
        // Update existing timer if needed
        if silenceTimer != nil {
            resetSilenceTimer()
        }
    }
    
    func startListening(with engine: AVAudioEngine) {
        // Verify we have a valid engine that's running
        guard engine.isRunning else {
            print("Cannot start listening - engine is not running")
            return
        }
        
        // Don't start if we don't have authorization
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("Speech recognition not authorized")
            requestAuthorization()
            return
        }
        
        // If already listening with the same engine and have a valid task, don't restart
        if isListening && self.audioEngine === engine && recognitionTask != nil {
            print("Already listening with valid task")
            return
        }
        
        // Stop any existing listening session first
        stopListening()
        
        // Ensure the isSpeechDetected is reset to false when starting
        DispatchQueue.main.async {
            self.isSpeechDetected = false
        }
        
        // Store reference to the provided engine
        self.audioEngine = engine
        
        // Ensure speech recognizer is available
        guard let speechRecognizer = self.speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        // Create and configure the speech recognition request
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = self.recognitionRequest else {
            print("Failed to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        // Get the input format
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        print("Setting up speech recognition with format: \(inputFormat)")
        
        self.currentInputNode = inputNode
        
        // Create tap block if needed
        if self.inputTap == nil {
            self.inputTap = { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
        }
        
        // Remove existing tap if installed
        if self.hasTapInstalled {
            self.currentInputNode?.removeTap(onBus: 0)
            self.hasTapInstalled = false
            // Small delay to ensure tap is removed
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // Install tap
        if let tap = self.inputTap {
            let bufferSize: AVAudioFrameCount = 1024
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat, block: tap)
            self.hasTapInstalled = true
            print("Installed new input tap for speech recognition")
        }
        
        // Configure the recognition task
        self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                if !result.bestTranscription.segments.isEmpty {
                    self.resetSilenceTimer()
                    if !self.isSpeechDetected {
                        self.isSpeechDetected = true
                        DispatchQueue.main.async {
                            self.onSpeechDetected?()
                        }
                    }
                }
            }
            
            if let error = error {
                print("Speech recognition error: \(error)")
                // Only stop for non-recoverable errors
                if (error as NSError).domain != "kAFAssistantErrorDomain" {
                    self.stopListening()
                }
            }
        }
        
        self.isListening = true
        print("Speech recognition started successfully")
    }
    
    func stopListening() {
        print("Speech recognition stopping - cleaning up resources")
        
        // Stop silence detection first
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Remove tap from input node if installed
        if hasTapInstalled, let node = currentInputNode {
            node.removeTap(onBus: 0)
            hasTapInstalled = false
            print("Removed input tap for speech recognition")
        }
        
        // End recognition request
        if let request = recognitionRequest {
            request.endAudio()
            recognitionRequest = nil
            print("Ended recognition request")
        }
        
        // Cancel and cleanup recognition task
        if let task = recognitionTask {
            task.finish()
            task.cancel()
            recognitionTask = nil
            print("Cancelled recognition task")
        }
        
        // Clear all references and state
        audioEngine = nil
        currentInputNode = nil
        inputTap = nil
        isListening = false
        isSpeechDetected = false
        
        print("Speech recognition stopped and all resources cleaned up")
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.isSpeechDetected {
                self.isSpeechDetected = false
                DispatchQueue.main.async {
                    self.onSilenceDetected?()
                }
            }
        }
    }
    
    @objc private func pauseDetectionThresholdChanged(_ notification: Notification) {
        if let threshold = notification.userInfo?["threshold"] as? Double {
            silenceThreshold = threshold
            defaultSilenceThreshold = threshold
            meetingSilenceThreshold = threshold
            print("🎙️ Updated pause detection threshold to: \(threshold) seconds")
            
            // If currently listening, reset the timer with new threshold
            if isListening && silenceTimer != nil {
                resetSilenceTimer()
            }
        }
    }
} 
