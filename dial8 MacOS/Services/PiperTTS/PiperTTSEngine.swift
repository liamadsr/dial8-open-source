import Foundation
import AVFoundation

/// Simplified Piper TTS Engine using system TTS as fallback
/// This will be replaced with actual Piper implementation once framework is properly integrated
class PiperTTSEngine: NSObject, ObservableObject {
    static let shared = PiperTTSEngine()
    
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentVoice: PiperVoice = .amyLow {
        didSet {
            UserDefaults.standard.set(currentVoice.rawValue, forKey: "PiperTTSVoice")
        }
    }
    @Published var speechRate: Float = 1.0 {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "PiperTTSSpeechRate")
        }
    }
    
    // MARK: - Voice Options
    enum PiperVoice: String, CaseIterable {
        case amyLow = "en_US-amy-low"
        case amyMedium = "en_US-amy-medium"
        case ryanHigh = "en_US-ryan-high"
        case dannyLow = "en_US-danny-low"
        case kathleenLow = "en_US-kathleen-low"
        case librittsHigh = "en_US-libritts_r-medium"
        
        var displayName: String {
            switch self {
            case .amyLow: return "Amy (Natural)"
            case .amyMedium: return "Amy (High Quality)"
            case .ryanHigh: return "Ryan (Male)"
            case .dannyLow: return "Danny (Male)"
            case .kathleenLow: return "Kathleen (Female)"
            case .librittsHigh: return "LibriTTS (Premium)"
            }
        }
        
        // Map to system voices for fallback
        var systemVoiceName: String? {
            switch self {
            case .amyLow, .amyMedium, .kathleenLow, .librittsHigh:
                return "Samantha" // Female voice
            case .ryanHigh, .dannyLow:
                return "Alex" // Male voice
            }
        }
    }
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private var completionHandler: (() -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        // Load saved preferences
        if let savedVoice = UserDefaults.standard.string(forKey: "PiperTTSVoice"),
           let voice = PiperVoice(rawValue: savedVoice) {
            self.currentVoice = voice
        }
        
        self.speechRate = UserDefaults.standard.float(forKey: "PiperTTSSpeechRate")
        if speechRate == 0 { speechRate = 1.0 }
        
        synthesizer.delegate = self
        
        print("🎤 PiperTTS: Initialized with voice: \(currentVoice.displayName)")
    }
    
    // MARK: - Public Methods
    
    /// Speak the given text
    func speak(text: String, completion: (() -> Void)? = nil) {
        // Stop any current playback
        stop()
        
        completionHandler = completion
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Try to use a voice that matches the selected Piper voice
        if let voiceName = currentVoice.systemVoiceName,
           let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.\(voiceName)") {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        // Start playback
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
    }
    
    /// Pause playback
    func pause() {
        guard isPlaying else { return }
        
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
        isPlaying = false
    }
    
    /// Resume playback
    func resume() {
        guard isPaused else { return }
        
        synthesizer.continueSpeaking()
        isPaused = false
        isPlaying = true
    }
    
    /// Stop playback
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        completionHandler = nil
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        }
    }
    
    /// Get available voices
    func getAvailableVoices() -> [PiperVoice] {
        return PiperVoice.allCases
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension PiperTTSEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isPlaying = true
        isPaused = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
        isPaused = false
        completionHandler?()
        completionHandler = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isPaused = true
        isPlaying = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isPaused = false
        isPlaying = true
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
        isPaused = false
        completionHandler = nil
    }
}