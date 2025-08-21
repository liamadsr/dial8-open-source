import Foundation
import AVFoundation

/// Piper TTS Engine using actual Piper voices via Sherpa-ONNX
class PiperTTSEngine: NSObject, ObservableObject {
    static let shared: PiperTTSEngine = {
        let instance = PiperTTSEngine()
        return instance
    }()
    
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var currentVoice: PiperVoice = .amy {
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
        case amy = "en_US-amy"
        case systemFallback = "system-default"
        
        var displayName: String {
            switch self {
            case .amy: return "Amy (Piper TTS)"
            case .systemFallback: return "System Voice (Fallback)"
            }
        }
    }
    
    // MARK: - Private Properties
    private var piperCore: PiperTTSCore?
    private let synthesizer = AVSpeechSynthesizer()  // Fallback
    private var completionHandler: (() -> Void)?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var isUsingPiper = false
    
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
        
        // Setup audio engine for Piper
        setupAudioEngine()
        
        // Initialize Piper TTS if Amy voice is selected
        if currentVoice == .amy {
            initializePiper()
        } else {
            isUsingPiper = false
        }
        
        print("🎤 PiperTTS: Initialized with voice: \(currentVoice.displayName)")
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            print("🎤 PiperTTS: Failed to start audio engine: \(error)")
        }
    }
    
    private func initializePiper() {
        // Only initialize if not already initialized
        if piperCore == nil {
            piperCore = PiperTTSCore(voice: .amy)
            isUsingPiper = piperCore != nil
            
            if isUsingPiper {
                print("🎤 PiperTTS: Using actual Piper TTS")
            } else {
                print("🎤 PiperTTS: Failed to initialize Piper, falling back to system TTS")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Speak the given text
    func speak(text: String, completion: (() -> Void)? = nil) {
        // Stop any current playback
        stop()
        
        completionHandler = completion
        
        // Try to use Piper TTS if available and selected
        if currentVoice == .amy && piperCore != nil {
            speakWithPiper(text: text, completion: completion)
        } else {
            // Fall back to system TTS
            speakWithSystem(text: text, completion: completion)
        }
    }
    
    private func speakWithPiper(text: String, completion: (() -> Void)? = nil) {
        guard let piperCore = piperCore else {
            speakWithSystem(text: text, completion: completion)
            return
        }
        
        print("🎤 PiperTTS: Generating speech with actual Piper TTS...")
        
        // Set playing state immediately to prevent HUD from dismissing
        isPlaying = true
        isPaused = false
        
        // Generate speech in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Generate audio
            guard let (audioData, sampleRate) = piperCore.generateSpeech(text: text, speed: self.speechRate) else {
                print("🎤 PiperTTS: Failed to generate speech, falling back to system")
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.speakWithSystem(text: text, completion: completion)
                }
                return
            }
            
            // Create temporary WAV file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("piper_tts_\(UUID().uuidString).wav")
            
            // Write WAV file
            if self.writeWAVFile(data: audioData, to: tempURL, sampleRate: Int(sampleRate)) {
                DispatchQueue.main.async {
                    self.playAudioFile(at: tempURL)
                }
            } else {
                print("🎤 PiperTTS: Failed to write audio file")
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.isPaused = false
                    completion?()
                }
            }
        }
    }
    
    private func speakWithSystem(text: String, completion: (() -> Void)? = nil) {
        print("🎤 PiperTTS: Using system TTS as fallback")
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Use default system voice
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
    }
    
    private func playAudioFile(at url: URL) {
        do {
            audioFile = try AVAudioFile(forReading: url)
            
            guard let audioFile = audioFile else {
                isPlaying = false
                isPaused = false
                completionHandler?()
                return
            }
            
            // Get the audio engine's output format
            let outputFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
            
            let buffer: AVAudioPCMBuffer
            
            // If formats don't match, we need to convert
            if audioFile.processingFormat != outputFormat {
                print("🎤 PiperTTS: Converting audio format from \(audioFile.processingFormat) to \(outputFormat)")
                
                // Create a converter
                guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: outputFormat) else {
                    print("🎤 PiperTTS: Failed to create audio converter")
                    isPlaying = false
                    isPaused = false
                    completionHandler?()
                    return
                }
                
                // Read the original file into a buffer
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                         frameCapacity: AVAudioFrameCount(audioFile.length)) else {
                    isPlaying = false
                    isPaused = false
                    completionHandler?()
                    return
                }
                
                try audioFile.read(into: inputBuffer)
                
                // Calculate output buffer size based on sample rate ratio
                let inputSampleRate = audioFile.processingFormat.sampleRate
                let outputSampleRate = outputFormat.sampleRate
                let sampleRateRatio = outputSampleRate / inputSampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(audioFile.length) * sampleRateRatio + 1000) // Add some buffer
                
                // Create output buffer with proper size
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                                          frameCapacity: outputFrameCapacity) else {
                    print("🎤 PiperTTS: Failed to create output buffer")
                    isPlaying = false
                    isPaused = false
                    completionHandler?()
                    return
                }
                
                // Convert the audio in a loop to handle all data
                var convertedFrameCount: AVAudioFrameCount = 0
                var inputFramePosition: AVAudioFramePosition = 0
                let inputFrameCount = inputBuffer.frameLength
                
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    if inputFramePosition >= inputFrameCount {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    
                    // Calculate how many frames to provide
                    let framesToProvide = min(inNumPackets, AVAudioPacketCount(inputFrameCount - AVAudioFrameCount(inputFramePosition)))
                    
                    // Create a sub-buffer view of the input
                    guard let subBuffer = AVAudioPCMBuffer(pcmFormat: inputBuffer.format,
                                                           frameCapacity: framesToProvide) else {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    
                    subBuffer.frameLength = framesToProvide
                    
                    // Copy the appropriate portion of input data
                    if let inputInt16 = inputBuffer.int16ChannelData,
                       let subInt16 = subBuffer.int16ChannelData {
                        for channel in 0..<Int(inputBuffer.format.channelCount) {
                            for frame in 0..<Int(framesToProvide) {
                                subInt16[channel][frame] = inputInt16[channel][Int(inputFramePosition) + frame]
                            }
                        }
                    } else if let inputFloat = inputBuffer.floatChannelData,
                              let subFloat = subBuffer.floatChannelData {
                        for channel in 0..<Int(inputBuffer.format.channelCount) {
                            for frame in 0..<Int(framesToProvide) {
                                subFloat[channel][frame] = inputFloat[channel][Int(inputFramePosition) + frame]
                            }
                        }
                    }
                    
                    inputFramePosition += AVAudioFramePosition(framesToProvide)
                    outStatus.pointee = .haveData
                    return subBuffer
                }
                
                // Keep converting until all input is processed
                while true {
                    var error: NSError?
                    let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                    
                    if status == .error {
                        print("🎤 PiperTTS: Conversion error: \(error?.localizedDescription ?? "unknown")")
                        isPlaying = false
                        isPaused = false
                        completionHandler?()
                        return
                    }
                    
                    convertedFrameCount += outputBuffer.frameLength
                    
                    if status == .endOfStream || inputFramePosition >= inputFrameCount {
                        break
                    }
                }
                
                outputBuffer.frameLength = convertedFrameCount
                buffer = outputBuffer
                print("🎤 PiperTTS: Converted \(inputFrameCount) frames to \(convertedFrameCount) frames")
                
            } else {
                // Formats match, just read directly
                guard let directBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                                          frameCapacity: AVAudioFrameCount(audioFile.length)) else {
                    print("🎤 PiperTTS: Failed to create buffer")
                    isPlaying = false
                    isPaused = false
                    completionHandler?()
                    return
                }
                try audioFile.read(into: directBuffer)
                buffer = directBuffer
            }
            
            // Disconnect and reconnect with the proper format
            audioEngine.disconnectNodeOutput(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
            
            // Schedule buffer
            playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    self?.completionHandler?()
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: url)
                }
            }
            
            // Start playback
            playerNode.play()
            // Note: isPlaying already set to true in speakWithPiper to prevent HUD dismissal
            
            print("🎤 PiperTTS: Playing Piper-generated audio (format: \(outputFormat))")
            
        } catch {
            print("🎤 PiperTTS: Failed to play audio: \(error)")
            isPlaying = false
            isPaused = false
            completionHandler?()
        }
    }
    
    private func writeWAVFile(data: Data, to url: URL, sampleRate: Int) -> Bool {
        let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                      sampleRate: Double(sampleRate),
                                      channels: 1,
                                      interleaved: false)
        
        guard let format = pcmFormat else { return false }
        
        do {
            let audioFile = try AVAudioFile(forWriting: url,
                                           settings: format.settings,
                                           commonFormat: .pcmFormatInt16,
                                           interleaved: false)
            
            // Create buffer from data
            let frameCount = data.count / 2 // 16-bit samples
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
                return false
            }
            
            buffer.frameLength = AVAudioFrameCount(frameCount)
            
            // Copy data to buffer
            data.withUnsafeBytes { bytes in
                let int16Pointer = bytes.bindMemory(to: Int16.self)
                if let channelData = buffer.int16ChannelData {
                    for i in 0..<frameCount {
                        channelData[0][i] = int16Pointer[i]
                    }
                }
            }
            
            try audioFile.write(from: buffer)
            return true
            
        } catch {
            print("🎤 PiperTTS: Failed to write WAV file: \(error)")
            return false
        }
    }
    
    /// Pause playback
    func pause() {
        guard isPlaying else { return }
        
        if isUsingPiper && currentVoice == .amy {
            playerNode.pause()
        } else {
            synthesizer.pauseSpeaking(at: .immediate)
        }
        isPaused = true
        isPlaying = false
    }
    
    /// Resume playback
    func resume() {
        guard isPaused else { return }
        
        if isUsingPiper && currentVoice == .amy {
            playerNode.play()
        } else {
            synthesizer.continueSpeaking()
        }
        isPaused = false
        isPlaying = true
    }
    
    /// Stop playback
    func stop() {
        playerNode.stop()
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        isUsingPiper = false
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