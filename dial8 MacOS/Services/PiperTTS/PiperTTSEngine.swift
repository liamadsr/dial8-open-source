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
    
    // Streaming properties
    private var isStreaming = false
    private var streamingBuffers: [AVAudioPCMBuffer] = []
    private var streamingQueue = DispatchQueue(label: "com.dial8.pipertts.streaming")
    private var totalSamplesGenerated: Int64 = 0
    private var totalSamplesScheduled: Int64 = 0
    
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
        
        // Use streaming for longer texts
        if text.count > 50 {
            print("🎤 PiperTTS: Using streaming TTS for text with \(text.count) characters")
            speakWithPiperStreaming(text: text, piperCore: piperCore, completion: completion)
        } else {
            print("🎤 PiperTTS: Using non-streaming TTS for short text")
            speakWithPiperNonStreaming(text: text, piperCore: piperCore, completion: completion)
        }
    }
    
    private func speakWithPiperStreaming(text: String, piperCore: PiperTTSCore, completion: (() -> Void)? = nil) {
        // Set playing state immediately
        isPlaying = true
        isPaused = false
        isUsingPiper = true
        isStreaming = true
        
        // Reset streaming state
        streamingBuffers.removeAll()
        totalSamplesGenerated = 0
        totalSamplesScheduled = 0
        
        // Start audio monitoring
        ttsAudioMonitor.startMonitoring()
        
        // Split text into chunks based on newlines and sentences
        let chunks = splitTextIntoNaturalChunks(text)
        print("🎤 PiperTTS: Split text into \(chunks.count) natural chunks")
        
        var hasStartedPlayback = false
        let startTime = Date()
        var sampleRate: Int32 = 22050
        
        // Generate speech for each chunk in background
        streamingQueue.async { [weak self] in
            guard let self = self else { return }
            
            for (index, chunk) in chunks.enumerated() {
                guard self.isPlaying else {
                    print("🎤 PiperTTS: Streaming cancelled at chunk \(index)")
                    break
                }
                
                // Generate audio for this chunk
                if let (audioData, chunkSampleRate) = piperCore.generateSpeech(text: chunk, speed: self.speechRate) {
                    if index == 0 {
                        sampleRate = chunkSampleRate
                    }
                    
                    // Create audio buffer
                    if let buffer = self.createStreamingBuffer(from: audioData, sampleRate: chunkSampleRate) {
                        self.totalSamplesGenerated += Int64(audioData.count / 2)
                        
                        DispatchQueue.main.async {
                            self.streamingBuffers.append(buffer)
                            
                            // Check if this will be the last buffer (we're on the last chunk)
                            let willBeLastBuffer = (index == chunks.count - 1)
                            
                            if !hasStartedPlayback {
                                hasStartedPlayback = true
                                let timeToFirstChunk = Date().timeIntervalSince(startTime)
                                print("🎤 PiperTTS: First chunk ready in \(String(format: "%.3f", timeToFirstChunk))s, starting playback")
                                self.startStreamingPlayback(sampleRate: sampleRate)
                            } else {
                                self.scheduleStreamingBuffer(buffer, isLast: willBeLastBuffer)
                            }
                            
                            // Don't update progress here - let the timer handle it based on actual playback
                            // Progress should reflect playback position, not generation progress
                        }
                        
                        print("🎤 PiperTTS: Generated chunk \(index + 1)/\(chunks.count): '\(chunk.prefix(30))...'")
                    }
                }
            }
            
            // Mark completion
            self.completionHandler = completion
            
            DispatchQueue.main.async {
                // Calculate duration based on output format (48000 Hz) not input format
                // The samples are generated at the input rate but played at output rate
                let outputSampleRate = self.audioEngine.mainMixerNode.outputFormat(forBus: 0).sampleRate
                let conversionRatio = outputSampleRate / Double(sampleRate)
                
                // Account for the fact that buffers are converted to output format
                self.audioDuration = Double(self.totalSamplesScheduled) / outputSampleRate
                
                // If no samples scheduled yet, estimate from generated samples
                if self.audioDuration == 0 {
                    self.audioDuration = Double(self.totalSamplesGenerated) / Double(sampleRate)
                }
                
                print("🎤 PiperTTS: All chunks generated. Total duration: \(String(format: "%.2f", self.audioDuration))s")
            }
        }
    }
    
    private func speakWithPiperNonStreaming(text: String, piperCore: PiperTTSCore, completion: (() -> Void)? = nil) {
        print("🎤 PiperTTS: Generating speech with non-streaming Piper TTS...")
        
        // Set playing state immediately to prevent HUD from dismissing
        isPlaying = true
        isPaused = false
        isUsingPiper = true
        isStreaming = false
        
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
                    self.isUsingPiper = false
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
                    self.isUsingPiper = false
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
        isStreaming = false
        completionHandler = nil
        progress = 0.0
        stopProgressTimer()
        ttsAudioMonitor.stopMonitoring()  // Stop TTS audio monitoring
        playbackStartTime = nil
        audioDuration = 0
        
        // Clear streaming state
        streamingBuffers.removeAll()
        totalSamplesGenerated = 0
        totalSamplesScheduled = 0
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
        guard let startTime = playbackStartTime else { return }
        
        if isStreaming {
            // For streaming, calculate progress based on what's been played vs total expected duration
            // We need to estimate total duration based on all chunks
            if totalSamplesGenerated > 0 && streamingBuffers.count > 0 {
                // Get current playback position
                let elapsed = Date().timeIntervalSince(startTime)
                
                // Estimate total duration from samples generated so far
                let currentGeneratedDuration = audioDuration
                
                if currentGeneratedDuration > 0 {
                    // Progress is based on elapsed time vs total duration
                    let currentProgress = Float(min(elapsed / currentGeneratedDuration, 1.0))
                    progress = currentProgress
                    
                    // Stop timer if playback finished
                    if currentProgress >= 1.0 {
                        stopProgressTimer()
                    }
                }
            }
        } else {
            // For non-streaming, use the original logic
            guard audioDuration > 0 else { return }
            
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
    
    // MARK: - Streaming Helper Methods
    
    private func splitTextIntoNaturalChunks(_ text: String) -> [String] {
        var chunks: [String] = []
        
        // First split by newlines to respect paragraph boundaries
        let paragraphs = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for paragraph in paragraphs {
            // For short paragraphs, keep them as one chunk
            if paragraph.count <= 150 {
                chunks.append(paragraph)
            } else {
                // For longer paragraphs, split by sentences
                let sentences = splitIntoSentences(paragraph)
                
                // Group sentences into reasonable chunks
                var currentChunk = ""
                for sentence in sentences {
                    if currentChunk.isEmpty {
                        currentChunk = sentence
                    } else if (currentChunk.count + sentence.count) <= 150 {
                        // Add to current chunk if it won't be too long
                        currentChunk += " " + sentence
                    } else {
                        // Save current chunk and start new one
                        chunks.append(currentChunk)
                        currentChunk = sentence
                    }
                }
                
                // Add any remaining text
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
            }
        }
        
        // If no chunks were created, just return the original text
        if chunks.isEmpty {
            chunks.append(text)
        }
        
        return chunks
    }
    
    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        
        // Use NSString for better sentence detection
        let nsText = text as NSString
        let options: NSString.EnumerationOptions = [.bySentences, .localized]
        
        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: options) { (substring, _, _, stop) in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                sentences.append(sentence)
            }
        }
        
        // Fallback if NSString enumeration doesn't work well
        if sentences.isEmpty {
            sentences = text.components(separatedBy: sentenceEnders)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) + "." }
                .filter { $0.count > 1 }
        }
        
        return sentences.isEmpty ? [text] : sentences
    }
    
    private func createStreamingBuffer(from audioData: Data, sampleRate: Int32) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                        sampleRate: Double(sampleRate),
                                        channels: 1,
                                        interleaved: false) else {
            print("🎤 PiperTTS: Failed to create audio format")
            return nil
        }
        
        let frameCount = audioData.count / 2  // 16-bit samples
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("🎤 PiperTTS: Failed to create buffer")
            return nil
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Copy PCM data to buffer
        audioData.withUnsafeBytes { bytes in
            let int16Pointer = bytes.bindMemory(to: Int16.self)
            if let channelData = buffer.int16ChannelData {
                for i in 0..<frameCount {
                    channelData[0][i] = int16Pointer[i]
                }
            }
        }
        
        return buffer
    }
    
    private func startStreamingPlayback(sampleRate: Int32) {
        // Ensure audio engine is running
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                print("🎤 PiperTTS: Failed to start audio engine: \(error)")
                return
            }
        }
        
        // Setup output format
        let outputFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        
        // Install tap for waveform monitoring
        playerNode.removeTap(onBus: 0)
        playerNode.installTap(onBus: 0, bufferSize: 1024, format: outputFormat) { [weak self] buffer, _ in
            self?.ttsAudioMonitor.processAudioBuffer(buffer)
        }
        
        // Schedule initial buffers
        // Important: Don't mark any as "last" here since more buffers will be added later
        for buffer in streamingBuffers {
            scheduleStreamingBuffer(buffer, isLast: false)
        }
        
        // Start playback
        playerNode.play()
        playbackStartTime = Date()
        progress = 0.0
        startProgressTimer()
        
        print("🎤 PiperTTS: Started streaming playback")
    }
    
    private func scheduleStreamingBuffer(_ buffer: AVAudioPCMBuffer, isLast: Bool = false) {
        let outputFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        
        // Convert format if needed
        if buffer.format != outputFormat {
            guard let converter = AVAudioConverter(from: buffer.format, to: outputFormat) else {
                print("🎤 PiperTTS: Failed to create converter")
                return
            }
            
            let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate + 1000)
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
                return
            }
            
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            
            if status == .error {
                print("🎤 PiperTTS: Conversion error: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            // Schedule converted buffer
            scheduleBuffer(outputBuffer, isLast: isLast)
        } else {
            // Direct scheduling
            scheduleBuffer(buffer, isLast: isLast)
        }
    }
    
    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer, isLast: Bool = false) {
        // Track samples at the actual playback rate
        totalSamplesScheduled += Int64(buffer.frameLength)
        
        // Update duration as we schedule buffers
        let outputSampleRate = buffer.format.sampleRate
        audioDuration = Double(totalSamplesScheduled) / outputSampleRate
        
        print("🎤 PiperTTS: Scheduling buffer, isLast: \(isLast)")
        
        playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            if isLast {
                print("🎤 PiperTTS: Last buffer finished playing, triggering completion")
                DispatchQueue.main.async {
                    self?.handleStreamingComplete()
                }
            }
        }
    }
    
    private func handleStreamingComplete() {
        print("🎤 PiperTTS: Streaming playback complete")
        isPlaying = false
        isPaused = false
        isStreaming = false
        progress = 1.0
        stopProgressTimer()
        ttsAudioMonitor.stopMonitoring()
        completionHandler?()
        completionHandler = nil
        
        // Clear streaming buffers
        streamingBuffers.removeAll()
        totalSamplesGenerated = 0
        totalSamplesScheduled = 0
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