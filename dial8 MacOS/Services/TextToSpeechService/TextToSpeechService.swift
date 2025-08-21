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
            // Save speed preference
            UserDefaults.standard.set(currentSpeed.rawValue, forKey: "TTSSpeed")
        }
    }
    @Published private(set) var isSpeaking: Bool = false
    @Published var currentText: String?
    @Published private(set) var progress: Float = 0.0
    
    // MARK: - Private Properties
    private let piperTTS = PiperTTSEngine.shared
    private var cancellables = Set<AnyCancellable>()
    private var totalCharacters: Int = 0
    private var charactersSpoken: Int = 0
    
    // MARK: - Initialization
    private override init() {
        super.init()
        
        // Load saved speed preference
        if let savedSpeed = UserDefaults.standard.object(forKey: "TTSSpeed") as? Float,
           let speed = TTSSpeed(rawValue: savedSpeed) {
            currentSpeed = speed
            print("🔊 TextToSpeechService: Loaded saved speed: \(speed.displayName)")
        }
        
        // Sync speed with PiperTTS
        piperTTS.speechRate = currentSpeed.rawValue
        
        // Observe PiperTTS state changes
        piperTTS.$isPlaying
            .sink { [weak self] isPlaying in
                if !isPlaying && self?.state == .playing {
                    self?.handleSpeechFinished()
                }
            }
            .store(in: &cancellables)
        
        print("🔊 TextToSpeechService: Initialized with Piper TTS")
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
        
        // Play sound effect when starting TTS (using ready sound)
        HUDSoundEffects.shared.playReadySound()
        
        // Update state
        state = .playing
        isSpeaking = true
        
        // Post notification that TTS started
        NotificationCenter.default.post(name: Notification.Name("TTSDidStart"), object: nil)
        
        // Start speaking with PiperTTS
        piperTTS.speak(text: text) { [weak self] in
            self?.handleSpeechFinished()
        }
    }
    
    func pause() {
        guard state == .playing else { return }
        
        print("🔊 TextToSpeechService: Pausing speech")
        piperTTS.pause()
        state = .paused
    }
    
    func resume() {
        guard state == .paused else { return }
        
        print("🔊 TextToSpeechService: Resuming speech")
        piperTTS.resume()
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
        piperTTS.stop()
        state = .idle  // Set to idle instead of stopped so UI shows correct state
        isSpeaking = false
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
        // Update PiperTTS speech rate
        piperTTS.speechRate = currentSpeed.rawValue
        
        // If currently speaking, we need to restart with new rate
        if state == .playing || state == .paused {
            let wasPlaying = state == .playing
            let currentPosition = charactersSpoken
            
            // Stop current speech
            piperTTS.stop()
            
            // Get remaining text
            if let text = currentText {
                let startIndex = text.index(text.startIndex, offsetBy: currentPosition, limitedBy: text.endIndex) ?? text.startIndex
                let remainingText = String(text[startIndex...])
                
                // Resume if was playing
                if wasPlaying {
                    piperTTS.speak(text: remainingText) { [weak self] in
                        self?.handleSpeechFinished()
                    }
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
    
    private func handleSpeechFinished() {
        print("🔊 TextToSpeechService: Speech finished")
        state = .idle
        isSpeaking = false
        progress = 1.0
        
        // Post notification
        NotificationCenter.default.post(name: Notification.Name("TTSDidFinish"), object: nil)
    }
}

// Note: AVSpeechSynthesizerDelegate has been removed as we're now using PiperTTS