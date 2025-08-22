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
    @Published var progress: Float = 0.0  // Track playback progress
    @Published var currentVoice: PiperVoiceModel? {
        didSet {
            // Only reinitialize if the voice actually changed
            if oldValue?.id != currentVoice?.id {
                reinitializePiper()
            }
        }
    }
    @Published var speechRate: Float = 1.0 {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "PiperTTSSpeechRate")
        }
    }
    
    // MARK: - Voice Manager
    private let voiceManager = PiperVoiceManager.shared
    
    // MARK: - Private Properties
    private var piperCore: PiperTTSCore?
    private let synthesizer = AVSpeechSynthesizer()  // Fallback
    private var completionHandler: (() -> Void)?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var isUsingPiper = false
    private var progressTimer: Timer?
    private var audioDuration: TimeInterval = 0
    private var playbackStartTime: Date?
    private var pausedProgress: Float = 0.0  // Store progress when paused
    
    // MARK: - Audio Monitor for TTS
    private let ttsAudioMonitor = TTSAudioMonitor.shared
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        // Get the selected voice from voice manager (it handles loading saved preferences)
        self.currentVoice = voiceManager.selectedVoice
        
        // If no voice selected but amy-low is available, use it (but don't trigger selection notification)
        if currentVoice == nil {
            if let amyLow = voiceManager.availableVoices.first(where: { $0.id == "amy-low" }) {
                if voiceManager.isVoiceDownloaded(amyLow) {
                    // Set directly without triggering notification during init
                    self.currentVoice = amyLow
                    voiceManager.selectedVoice = amyLow
                    UserDefaults.standard.set(amyLow.id, forKey: "SelectedPiperVoice")
                }
            }
        }
        
        self.speechRate = UserDefaults.standard.float(forKey: "PiperTTSSpeechRate")
        if speechRate == 0 { speechRate = 1.0 }
        
        synthesizer.delegate = self
        
        // Setup audio engine for Piper
        setupAudioEngine()
        
        // Observe voice selection changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceChanged(_:)),
            name: NSNotification.Name("PiperVoiceSelectionChanged"),
            object: nil
        )
        
        // Initialize Piper TTS if a voice is selected
        if currentVoice != nil {
            initializePiper()
        } else {
            isUsingPiper = false
        }
        
        print("🎤 PiperTTS: Initialized with voice: \(currentVoice?.displayName ?? "none")")
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
        print("🎤 PiperTTS: initializePiper() called")
        
        // Only initialize if not already initialized
        if piperCore == nil, let voice = currentVoice {
            print("🎤 PiperTTS: Attempting to initialize with voice: \(voice.displayName)")
            
            // Ensure voice is downloaded before initializing
            if voiceManager.isVoiceDownloaded(voice) {
                print("🎤 PiperTTS: Voice is downloaded, creating PiperTTSCore...")
                piperCore = PiperTTSCore(voiceModel: voice)
                isUsingPiper = piperCore != nil
                
                if isUsingPiper {
                    print("🎤 PiperTTS: Successfully initialized with \(voice.displayName)")
                } else {
                    print("⚠️ PiperTTS: Failed to initialize PiperTTSCore, falling back to system voice")
                }
            } else {
                print("⚠️ PiperTTS: Voice \(voice.displayName) not downloaded, cannot initialize")
                isUsingPiper = false
            }
        } else {
            print("🎤 PiperTTS: Skipping initialization - piperCore: \(piperCore != nil), currentVoice: \(currentVoice?.displayName ?? "nil")")
        }
    }
    
    private var isReinitializing = false
    
    private func reinitializePiper() {
        // Prevent concurrent re-initialization
        guard !isReinitializing else {
            print("🎤 PiperTTS: Re-initialization already in progress, skipping")
            return
        }
        
        print("🎤 PiperTTS: Starting re-initialization...")
        isReinitializing = true
        
        // Stop any ongoing speech first
        stop()
        
        // Clean up and reinitialize synchronously to avoid race conditions
        // Clear the old instance
        self.piperCore = nil
        self.isUsingPiper = false
        
        // Initialize with new voice if available and downloaded
        if let voice = self.currentVoice {
            print("🎤 PiperTTS: Current voice: \(voice.displayName) (id: \(voice.id))")
            
            if self.voiceManager.isVoiceDownloaded(voice) {
                print("🎤 PiperTTS: Voice is downloaded, creating PiperTTSCore...")
                self.piperCore = PiperTTSCore(voiceModel: voice)
                self.isUsingPiper = self.piperCore != nil
                
                if self.isUsingPiper {
                    print("🎤 PiperTTS: Re-initialized successfully with \(voice.displayName)")
                } else {
                    print("⚠️ PiperTTS: Failed to create PiperTTSCore with \(voice.displayName)")
                }
            } else {
                print("⚠️ PiperTTS: Voice not downloaded: \(voice.displayName)")
            }
        } else {
            print("⚠️ PiperTTS: No voice selected for re-initialization")
        }
        
        isReinitializing = false
        print("🎤 PiperTTS: Re-initialization complete - isUsingPiper: \(isUsingPiper)")
    }
    
    @objc private func voiceChanged(_ notification: Notification) {
        if let voice = notification.userInfo?["voice"] as? PiperVoiceModel {
            // Prevent re-selecting the same voice
            guard voice.id != currentVoice?.id else { return }
            self.currentVoice = voice
            
            // Save the selection
            UserDefaults.standard.set(voice.id, forKey: "PiperTTSVoice")
            
            // Reinitialize with the new voice
            reinitializePiper()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Speak the given text
    func speak(text: String, completion: (() -> Void)? = nil) {
        // Stop any current playback
        stop()
        
        completionHandler = completion
        
        print("🎤 PiperTTS: speak() called - currentVoice: \(currentVoice?.displayName ?? "nil"), piperCore: \(piperCore != nil ? "exists" : "nil")")
        
        // Try to use Piper TTS if available and selected
        if currentVoice != nil && piperCore != nil {
            speakWithPiper(text: text, completion: completion)
        } else {
            // Fall back to system TTS
            print("🎤 PiperTTS: Falling back to system TTS - voice: \(currentVoice?.displayName ?? "nil"), core: \(piperCore != nil)")
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
        isUsingPiper = true  // Mark that we're using Piper for this playback
        
        // Start audio monitoring for TTS waveform
        ttsAudioMonitor.startMonitoring()
        
        // Generate speech in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Generate audio
            guard let (audioData, sampleRate) = piperCore.generateSpeech(text: text, speed: self.speechRate) else {
                print("🎤 PiperTTS: Failed to generate speech, falling back to system")
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.isUsingPiper = false  // Reset flag since we're falling back
                    self.speakWithSystem(text: text, completion: completion)
                }
                return
            }
            
            // Create temporary WAV file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("piper_tts_\(UUID().uuidString).wav")
            
            // Write WAV file
            if self.writeWAVFile(data: audioData, to: tempURL, sampleRate: Int(sampleRate)) {
                // Calculate true duration from original audio data
                let originalSampleCount = audioData.count / 2  // 16-bit samples = 2 bytes each
                let originalDuration = Double(originalSampleCount) / Double(sampleRate)
                // Add adjustment factor for processing delays and potential silence
                let adjustedDuration = originalDuration * 1.2  // Add 20% to account for delays
                
                DispatchQueue.main.async {
                    self.playAudioFile(at: tempURL, originalDuration: adjustedDuration)
                }
            } else {
                print("🎤 PiperTTS: Failed to write audio file")
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.isPaused = false
                    self.isUsingPiper = false  // Reset flag
                    completion?()
                }
            }
        }
    }
    
    private func speakWithSystem(text: String, completion: (() -> Void)? = nil) {
        print("🎤 PiperTTS: Using system TTS as fallback")
        
        // Reset progress for system TTS
        progress = 0.0
        isUsingPiper = false  // Mark that we're using system TTS
        
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
    
    private func playAudioFile(at url: URL, originalDuration: TimeInterval? = nil) {
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
            
            // Remove old tap and install new one with TTS audio monitor
            playerNode.removeTap(onBus: 0)
            playerNode.installTap(onBus: 0, bufferSize: 1024, format: outputFormat) { [weak self] buffer, time in
                // Send audio buffer to TTS monitor for visualization
                self?.ttsAudioMonitor.processAudioBuffer(buffer)
            }
            
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
            
            // Schedule buffer
            playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    self?.progress = 1.0  // Ensure progress shows complete
                    self?.stopProgressTimer()
                    self?.ttsAudioMonitor.stopMonitoring()  // Stop TTS audio monitoring
                    self?.completionHandler?()
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: url)
                }
            }
            
            // Use the original duration if provided, otherwise calculate from buffer
            if let originalDuration = originalDuration {
                audioDuration = originalDuration
            } else {
                // Fallback: calculate from buffer (might be less accurate due to conversion)
                let totalFrames = buffer.frameLength
                let sampleRate = outputFormat.sampleRate
                audioDuration = Double(totalFrames) / sampleRate
            }
            
            // Start playback
            playerNode.play()
            playbackStartTime = Date()
            progress = 0.0
            
            // Start progress timer
            startProgressTimer()
            
            // Note: isPlaying already set to true in speakWithPiper to prevent HUD dismissal
            
            print("🎤 PiperTTS: Playing Piper-generated audio (format: \(outputFormat), duration: \(audioDuration)s)")
            
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
        
        // Set paused state FIRST to avoid race condition with observers
        isPaused = true
        isPlaying = false
        
        if isUsingPiper && currentVoice != nil {
            playerNode.pause()
            stopProgressTimer()
            pausedProgress = progress  // Save current progress
        } else {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    /// Resume playback
    func resume() {
        guard isPaused else { return }
        
        // Set playing state FIRST to avoid race condition with observers
        isPaused = false
        isPlaying = true
        
        if isUsingPiper && currentVoice != nil {
            playerNode.play()
            // Resume from paused progress
            let remainingDuration = audioDuration * Double(1.0 - pausedProgress)
            playbackStartTime = Date().addingTimeInterval(-Double(pausedProgress) * audioDuration)
            startProgressTimer()
        } else {
            synthesizer.continueSpeaking()
        }
    }
    
    /// Stop playback
    func stop() {
        playerNode.stop()
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        isUsingPiper = false
        completionHandler = nil
        progress = 0.0
        stopProgressTimer()
        ttsAudioMonitor.stopMonitoring()  // Stop TTS audio monitoring
        playbackStartTime = nil
        audioDuration = 0
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
    func getAvailableVoices() -> [PiperVoiceModel] {
        return voiceManager.availableVoices
    }
    
    // MARK: - Progress Tracking
    
    private func startProgressTimer() {
        stopProgressTimer()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let startTime = playbackStartTime,
              audioDuration > 0 else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let currentProgress = Float(min(elapsed / audioDuration, 1.0))
        
        // Update progress
        progress = currentProgress
        
        // Stop timer if playback finished
        if currentProgress >= 1.0 {
            stopProgressTimer()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension PiperTTSEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isPlaying = true
        isPaused = false
        progress = 0.0
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Update progress based on character position
        let totalLength = utterance.speechString.count
        if totalLength > 0 {
            let currentPosition = characterRange.location + characterRange.length
            progress = Float(currentPosition) / Float(totalLength)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
        isPaused = false
        progress = 1.0
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
        progress = 0.0
        completionHandler = nil
    }
}