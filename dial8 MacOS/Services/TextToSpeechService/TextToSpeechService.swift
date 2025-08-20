import Foundation
import AVFoundation
import Combine

enum TTSState {
    case idle
    case playing
    case paused
    case stopped
}

enum TTSSpeed: Float, CaseIterable {
    case slow = 0.75
    case normal = 1.0
    case fast = 1.25
    case faster = 1.5
    case fastest = 2.0
    
    var displayName: String {
        switch self {
        case .slow: return "0.75x"
        case .normal: return "1.0x"
        case .fast: return "1.25x"
        case .faster: return "1.5x"
        case .fastest: return "2.0x"
        }
    }
}

class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()
    
    // MARK: - Published Properties
    @Published private(set) var state: TTSState = .idle
    @Published var currentSpeed: TTSSpeed = .normal {
        didSet {
            updateSpeechRate()
        }
    }
    @Published private(set) var isSpeaking: Bool = false
    @Published var currentText: String?
    @Published private(set) var progress: Float = 0.0
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var pausedRange: NSRange?
    private var totalCharacters: Int = 0
    private var charactersSpoken: Int = 0
    
    // MARK: - Initialization
    private override init() {
        super.init()
        synthesizer.delegate = self
        
        print("🔊 TextToSpeechService: Initialized")
    }
    
    // MARK: - Public Methods
    
    func speak(text: String) {
        print("🔊 TextToSpeechService: Starting to speak text with \(text.count) characters")
        
        // Stop any current speech
        stop()
        
        // Store the text
        currentText = text
        totalCharacters = text.count
        charactersSpoken = 0
        progress = 0.0
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = currentSpeed.rawValue * AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Use the default system voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        currentUtterance = utterance
        
        // Start speaking
        synthesizer.speak(utterance)
        state = .playing
        isSpeaking = true
        
        // Post notification that TTS started
        NotificationCenter.default.post(name: Notification.Name("TTSDidStart"), object: nil)
    }
    
    func pause() {
        guard state == .playing else { return }
        
        print("🔊 TextToSpeechService: Pausing speech")
        synthesizer.pauseSpeaking(at: .immediate)
        state = .paused
    }
    
    func resume() {
        guard state == .paused else { return }
        
        print("🔊 TextToSpeechService: Resuming speech")
        synthesizer.continueSpeaking()
        state = .playing
    }
    
    func togglePlayPause() {
        switch state {
        case .playing:
            pause()
        case .paused:
            resume()
        case .idle, .stopped:
            if let text = currentText {
                speak(text: text)
            }
        }
    }
    
    func stop() {
        guard state != .idle else { return }
        
        print("🔊 TextToSpeechService: Stopping speech")
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle  // Set to idle instead of stopped so UI shows correct state
        isSpeaking = false
        currentUtterance = nil
        progress = 0.0
        charactersSpoken = 0
        
        // Post notification that TTS stopped
        NotificationCenter.default.post(name: Notification.Name("TTSDidStop"), object: nil)
    }
    
    func setSpeed(_ speed: TTSSpeed) {
        currentSpeed = speed
    }
    
    // MARK: - Private Methods
    
    private func updateSpeechRate() {
        guard let utterance = currentUtterance else { return }
        
        // If currently speaking, we need to restart with new rate
        if state == .playing || state == .paused {
            let wasPlaying = state == .playing
            let currentPosition = charactersSpoken
            
            // Stop current speech
            synthesizer.stopSpeaking(at: .immediate)
            
            // Get remaining text
            if let text = currentText {
                let startIndex = text.index(text.startIndex, offsetBy: currentPosition, limitedBy: text.endIndex) ?? text.startIndex
                let remainingText = String(text[startIndex...])
                
                // Create new utterance with remaining text
                let newUtterance = AVSpeechUtterance(string: remainingText)
                newUtterance.rate = currentSpeed.rawValue * AVSpeechUtteranceDefaultSpeechRate
                newUtterance.pitchMultiplier = 1.0
                newUtterance.volume = 1.0
                
                if let voice = AVSpeechSynthesisVoice(language: "en-US") {
                    newUtterance.voice = voice
                }
                
                currentUtterance = newUtterance
                
                // Resume if was playing
                if wasPlaying {
                    synthesizer.speak(newUtterance)
                    state = .playing
                }
            }
        }
    }
    
    private func updateProgress(range: NSRange) {
        charactersSpoken = range.location + range.length
        if totalCharacters > 0 {
            progress = Float(charactersSpoken) / Float(totalCharacters)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 TextToSpeechService: Speech started")
        state = .playing
        isSpeaking = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 TextToSpeechService: Speech finished")
        state = .idle
        isSpeaking = false
        currentUtterance = nil
        progress = 1.0
        
        // Post notification
        NotificationCenter.default.post(name: Notification.Name("TTSDidFinish"), object: nil)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("🔊 TextToSpeechService: Speech paused")
        state = .paused
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("🔊 TextToSpeechService: Speech resumed")
        state = .playing
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🔊 TextToSpeechService: Speech cancelled")
        state = .stopped
        isSpeaking = false
        currentUtterance = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        updateProgress(range: characterRange)
    }
}