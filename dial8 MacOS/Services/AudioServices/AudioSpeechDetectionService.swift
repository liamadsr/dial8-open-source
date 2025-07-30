import Foundation
import AVFoundation
import Combine

class AudioSpeechDetectionService: ObservableObject {
    // Published properties for state tracking
    @Published private(set) var isSpeechDetected = false
    @Published private(set) var lastSpeechDetectedTime: Date?
    @Published private(set) var isProcessingSpeech = false
    
    // Dependencies
    private let speechRecognizer = AppleSpeechRecognizer.shared
    private let audioTranscriptionService = AudioTranscriptionService.shared
    
    // Recording mode
    private var currentRecordingMode: RecordingMode?
    
    // Callbacks for speech events
    var onSpeechDetected: (() -> Void)?
    var onSilenceDetected: (() -> Void)?
    
    init() {
        setupSpeechRecognition()
    }
    
    func setRecordingMode(_ mode: RecordingMode?) {
        self.currentRecordingMode = mode
        
        // Pass the recording mode to the speech recognizer
        speechRecognizer.setRecordingMode(mode)
    }
    
    private func setupSpeechRecognition() {
        speechRecognizer.onSpeechDetected = { [weak self] in
            guard let self = self else { return }
            
            // Get current time and generate a unique ID for this detection event for better logging
            let now = Date()
            let detectionId = String(Int.random(in: 1000...9999))
            
            print("🗣️ [ID:\(detectionId)] Speech detected at \(DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .medium))")
            
            // Always update the timestamp with a buffer to ensure we don't miss speech
            let bufferTime = -3.0  // Increased buffer to capture more context
            self.lastSpeechDetectedTime = now.addingTimeInterval(bufferTime)
            print("📊 [ID:\(detectionId)] Updated speech detection timestamp with \(abs(bufferTime))s buffer")
            
            self.isProcessingSpeech = true
            DispatchQueue.main.async {
                self.isSpeechDetected = true
                
                // Notify callback
                self.onSpeechDetected?()
            }
        }
        
        speechRecognizer.onSilenceDetected = { [weak self] in
            guard let self = self else { return }
            print("🤫 Silence detected")
            DispatchQueue.main.async {
                self.isSpeechDetected = false
            }
            
            // Notify TranscriptionResultHandler of silence
            TranscriptionResultHandler.shared.handleSilenceDetected()
            
            // Notify callback
            self.onSilenceDetected?()
            
            // Update state
            self.isProcessingSpeech = false
        }
    }
    
    func startSpeechDetection(with engine: AVAudioEngine) {
        // Reset state and start speech detection
        self.lastSpeechDetectedTime = nil  // Don't set an offset that could trigger immediate detection
        self.isProcessingSpeech = false
        
        // Explicitly set isSpeechDetected to false when starting
        DispatchQueue.main.async {
            self.isSpeechDetected = false
        }
        
        print("🎤 Starting speech detection")
        speechRecognizer.startListening(with: engine)
    }
    
    func stopSpeechDetection() {
        print("🛑 Stopping speech detection")
        speechRecognizer.stopListening()
        
        // Reset speech detection state
        self.lastSpeechDetectedTime = nil
        self.isProcessingSpeech = false
        
        // Ensure speech detection state is reset
        DispatchQueue.main.async {
            self.isSpeechDetected = false
        }
    }
    
    func hasSpeechBeenDetectedRecently(threshold: TimeInterval = 3.0) -> Bool {
        guard let lastSpeechTime = lastSpeechDetectedTime else {
            return false
        }
        
        let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeechTime)
        return timeSinceLastSpeech < threshold
    }
    
    func getLastSpeechTime() -> Date? {
        return lastSpeechDetectedTime
    }
    
    deinit {
        speechRecognizer.stopListening()
    }
} 