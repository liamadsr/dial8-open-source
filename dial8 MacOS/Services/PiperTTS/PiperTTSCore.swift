import Foundation
import AVFoundation

// MARK: - C Bridge Functions
@_silgen_name("createPiperTtsConfig")
func createPiperTtsConfig(_ modelPath: UnsafePointer<CChar>?, _ tokensPath: UnsafePointer<CChar>?, _ dataDir: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?

@_silgen_name("freePiperTtsConfig")
func freePiperTtsConfig(_ config: UnsafeMutableRawPointer?)

// MARK: - Generated Audio Struct (must match C layout)
struct SherpaOnnxGeneratedAudio {
    var samples: UnsafePointer<Float>?
    var n: Int32  // number of samples
    var sample_rate: Int32
}

// MARK: - C API Imports from Dynamic Library
typealias CreateOfflineTtsFunc = @convention(c) (UnsafeRawPointer?) -> OpaquePointer?
typealias DestroyOfflineTtsFunc = @convention(c) (OpaquePointer?) -> Void
typealias GenerateAudioFunc = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int32, Float) -> UnsafeRawPointer?
typealias DestroyAudioFunc = @convention(c) (UnsafeRawPointer?) -> Void

/// Core Piper TTS implementation using Sherpa-ONNX
class PiperTTSCore {
    private var ttsHandle: OpaquePointer?
    private let dylibHandle: UnsafeMutableRawPointer?
    
    // Function pointers
    private var createTts: CreateOfflineTtsFunc?
    private var destroyTts: DestroyOfflineTtsFunc?
    private var generateAudio: GenerateAudioFunc?
    private var destroyAudio: DestroyAudioFunc?
    
    enum PiperVoice: String, CaseIterable {
        case amy = "en_US-amy-low"
        
        var displayName: String {
            switch self {
            case .amy: return "Amy (Piper TTS)"
            }
        }
        
        var modelPath: String {
            // Try bundle first
            if let path = Bundle.main.path(forResource: "en_US-amy-low", ofType: "onnx", inDirectory: "PiperModels/en_US-amy-low") {
                return path
            }
            // Fallback to absolute path for development
            return "/Users/liamalizadeh/code/open-source/dial8-open-source/Resources/PiperModels/en_US-amy-low/en_US-amy-low.onnx"
        }
        
        var tokensPath: String {
            // Try bundle first
            if let path = Bundle.main.path(forResource: "tokens", ofType: "txt", inDirectory: "PiperModels/en_US-amy-low") {
                return path
            }
            // Fallback to absolute path for development
            return "/Users/liamalizadeh/code/open-source/dial8-open-source/Resources/PiperModels/en_US-amy-low/tokens.txt"
        }
        
        var espeakDataPath: String {
            // Try bundle first
            if let path = Bundle.main.path(forResource: nil, ofType: nil, inDirectory: "PiperModels/espeak-ng-data") {
                return path
            }
            // Fallback to absolute path for development
            return "/Users/liamalizadeh/code/open-source/dial8-open-source/Resources/PiperModels/espeak-ng-data"
        }
    }
    
    init?(voice: PiperVoice = .amy) {
        // Load dynamic library
        var loadPath: String? = Bundle.main.path(forResource: "libsherpa-onnx-c", ofType: "dylib", inDirectory: "Frameworks")
        
        if loadPath == nil {
            print("🎤 PiperTTS: Failed to find libsherpa-onnx-c.dylib in bundle")
            // Try alternative path
            let altPath = "/Users/liamalizadeh/code/open-source/dial8-open-source/Resources/Frameworks/libsherpa-onnx-c.dylib"
            if FileManager.default.fileExists(atPath: altPath) {
                print("🎤 PiperTTS: Using alternative path: \(altPath)")
                loadPath = altPath
            }
        }
        
        guard let path = loadPath else {
            print("🎤 PiperTTS: Could not find libsherpa-onnx-c.dylib")
            return nil
        }
        
        dylibHandle = dlopen(path, RTLD_NOW)
        guard dylibHandle != nil else {
            if let error = dlerror() {
                print("🎤 PiperTTS: Failed to load library: \(String(cString: error))")
            } else {
                print("🎤 PiperTTS: Failed to load library: unknown error")
            }
            return nil
        }
        
        // Initialize function pointers to nil first
        self.createTts = nil
        self.destroyTts = nil
        self.generateAudio = nil
        self.destroyAudio = nil
        
        // Load function pointers
        if let sym = dlsym(dylibHandle, "SherpaOnnxCreateOfflineTts") {
            self.createTts = unsafeBitCast(sym, to: CreateOfflineTtsFunc.self)
            print("🎤 PiperTTS: Loaded SherpaOnnxCreateOfflineTts")
        } else {
            print("🎤 PiperTTS: Failed to load SherpaOnnxCreateOfflineTts")
        }
        
        if let sym = dlsym(dylibHandle, "SherpaOnnxDestroyOfflineTts") {
            self.destroyTts = unsafeBitCast(sym, to: DestroyOfflineTtsFunc.self)
            print("🎤 PiperTTS: Loaded SherpaOnnxDestroyOfflineTts")
        } else {
            print("🎤 PiperTTS: Failed to load SherpaOnnxDestroyOfflineTts")
        }
        
        if let sym = dlsym(dylibHandle, "SherpaOnnxOfflineTtsGenerate") {
            self.generateAudio = unsafeBitCast(sym, to: GenerateAudioFunc.self)
            print("🎤 PiperTTS: Loaded SherpaOnnxOfflineTtsGenerate")
        } else {
            print("🎤 PiperTTS: Failed to load SherpaOnnxOfflineTtsGenerate")
        }
        
        if let sym = dlsym(dylibHandle, "SherpaOnnxDestroyOfflineTtsGeneratedAudio") {
            self.destroyAudio = unsafeBitCast(sym, to: DestroyAudioFunc.self)
            print("🎤 PiperTTS: Loaded SherpaOnnxDestroyOfflineTtsGeneratedAudio")
        } else {
            print("🎤 PiperTTS: Failed to load SherpaOnnxDestroyOfflineTtsGeneratedAudio")
        }
        
        guard self.createTts != nil, self.destroyTts != nil, self.generateAudio != nil, self.destroyAudio != nil else {
            print("🎤 PiperTTS: Critical functions not loaded")
            if dylibHandle != nil {
                dlclose(dylibHandle)
            }
            return nil
        }
        
        // Check if model files exist
        let modelPath = voice.modelPath
        let tokensPath = voice.tokensPath
        let espeakPath = voice.espeakDataPath
        
        print("🎤 PiperTTS: Model path: \(modelPath)")
        print("🎤 PiperTTS: Tokens path: \(tokensPath)")
        print("🎤 PiperTTS: Espeak path: \(espeakPath)")
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("🎤 PiperTTS: Model file not found at \(modelPath)")
            if dylibHandle != nil {
                dlclose(dylibHandle)
            }
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: tokensPath) else {
            print("🎤 PiperTTS: Tokens file not found at \(tokensPath)")
            if dylibHandle != nil {
                dlclose(dylibHandle)
            }
            return nil
        }
        
        print("🎤 PiperTTS: Creating TTS config using bridge...")
        
        // Create config using C bridge to ensure proper memory layout
        let configPtr = modelPath.withCString { modelCStr in
            tokensPath.withCString { tokensCStr in
                espeakPath.withCString { espeakCStr in
                    createPiperTtsConfig(modelCStr, tokensCStr, espeakCStr)
                }
            }
        }
        
        guard let config = configPtr else {
            print("🎤 PiperTTS: Failed to create config")
            if dylibHandle != nil {
                dlclose(dylibHandle)
            }
            return nil
        }
        
        defer {
            freePiperTtsConfig(config)
        }
        
        print("🎤 PiperTTS: Calling SherpaOnnxCreateOfflineTts...")
        
        // Create TTS instance
        ttsHandle = createTts?(config)
        
        print("🎤 PiperTTS: TTS handle: \(String(describing: ttsHandle))")
        
        guard ttsHandle != nil else {
            print("🎤 PiperTTS: Failed to create TTS instance - handle is nil")
            if dylibHandle != nil {
                dlclose(dylibHandle)
            }
            return nil
        }
        
        print("🎤 PiperTTS: Successfully initialized with voice: \(voice.displayName)")
    }
    
    deinit {
        if let handle = ttsHandle {
            destroyTts?(handle)
        }
        if let handle = dylibHandle {
            dlclose(handle)
        }
    }
    
    /// Generate speech audio data
    func generateSpeech(text: String, speakerId: Int32 = 0, speed: Float = 1.0) -> (data: Data, sampleRate: Int32)? {
        // Return nil if TTS handle is not available (will fall back to system TTS)
        guard let ttsHandle = ttsHandle else {
            print("🎤 PiperTTS: TTS handle not available, falling back")
            return nil
        }
        
        print("🎤 PiperTTS: TTS handle exists: \(ttsHandle)")
        
        guard let generateAudio = generateAudio else {
            print("🎤 PiperTTS: generateAudio function not loaded")
            return nil
        }
        
        guard let destroyAudio = destroyAudio else {
            print("🎤 PiperTTS: destroyAudio function not loaded")
            return nil
        }
        
        print("🎤 PiperTTS: Generating audio for text: '\(text.prefix(50))...'")
        
        // Generate audio
        let audioHandle = text.withCString { cText in
            let result = generateAudio(ttsHandle, cText, speakerId, speed)
            print("🎤 PiperTTS: Audio generation result: \(String(describing: result))")
            return result
        }
        
        guard let audioPtr = audioHandle else {
            print("🎤 PiperTTS: Failed to generate audio - audioHandle is nil")
            return nil
        }
        defer { destroyAudio(audioPtr) }
        
        print("🎤 PiperTTS: Audio handle created: \(audioPtr)")
        
        // Cast to the struct pointer and access it
        let audio = audioPtr.assumingMemoryBound(to: SherpaOnnxGeneratedAudio.self)
        let audioStruct = audio.pointee
        let sampleRate = audioStruct.sample_rate
        let numSamples = audioStruct.n
        let samples = audioStruct.samples
        
        print("🎤 PiperTTS: Sample rate: \(sampleRate), Num samples: \(numSamples)")
        
        guard numSamples > 0,
              let samples = samples else {
            print("🎤 PiperTTS: No audio samples generated")
            return nil
        }
        
        // Convert float samples to PCM16
        var pcmData = Data()
        pcmData.reserveCapacity(Int(numSamples) * 2)
        
        for i in 0..<Int(numSamples) {
            let sample = samples[i]
            let pcm16 = Int16(max(-32768, min(32767, sample * 32767)))
            withUnsafeBytes(of: pcm16) { bytes in
                pcmData.append(contentsOf: bytes)
            }
        }
        
        print("🎤 PiperTTS: Generated \(numSamples) samples at \(sampleRate)Hz")
        return (pcmData, sampleRate)
    }
}

// MARK: - C Structure Definitions (No longer needed with bridge)
/*
private struct OfflineTtsVitsModelConfig {
    var model: UnsafeMutablePointer<CChar>?
    var lexicon: UnsafeMutablePointer<CChar>?
    var tokens: UnsafeMutablePointer<CChar>?
    var data_dir: UnsafeMutablePointer<CChar>?
    var noise_scale: Float
    var noise_scale_w: Float
    var length_scale: Float
    var dict_dir: UnsafeMutablePointer<CChar>?
    
    init() {
        model = nil
        lexicon = nil
        tokens = nil
        data_dir = nil
        noise_scale = 0.667
        noise_scale_w = 0.8
        length_scale = 1.0
        dict_dir = nil
    }
}

// Empty structs for unused model types
private struct OfflineTtsMatchaModelConfig {
    var acoustic_model: UnsafeMutablePointer<CChar>?
    var vocoder: UnsafeMutablePointer<CChar>?
    var lexicon: UnsafeMutablePointer<CChar>?
    var tokens: UnsafeMutablePointer<CChar>?
    var data_dir: UnsafeMutablePointer<CChar>?
    var noise_scale: Float
    var length_scale: Float
    
    init() {
        acoustic_model = nil
        vocoder = nil
        lexicon = nil
        tokens = nil
        data_dir = nil
        noise_scale = 0
        length_scale = 0
    }
}

private struct OfflineTtsKokoroModelConfig {
    var model: UnsafeMutablePointer<CChar>?
    var voices: UnsafeMutablePointer<CChar>?
    var vocode: UnsafeMutablePointer<CChar>?
    var num_tasks: Int32
    
    init() {
        model = nil
        voices = nil
        vocode = nil
        num_tasks = 0
    }
}

private struct OfflineTtsKittenModelConfig {
    var encoder: UnsafeMutablePointer<CChar>?
    var embedding: UnsafeMutablePointer<CChar>?
    var t2s: UnsafeMutablePointer<CChar>?
    var vocoder: UnsafeMutablePointer<CChar>?
    var lexicon: UnsafeMutablePointer<CChar>?
    var tokens: UnsafeMutablePointer<CChar>?
    var data_dir: UnsafeMutablePointer<CChar>?
    var length_scale: Float
    
    init() {
        encoder = nil
        embedding = nil
        t2s = nil
        vocoder = nil
        lexicon = nil
        tokens = nil
        data_dir = nil
        length_scale = 0
    }
}

private struct OfflineTtsModelConfig {
    var vits: OfflineTtsVitsModelConfig
    var num_threads: Int32
    var debug: Int32
    var provider: UnsafeMutablePointer<CChar>?
    var matcha: OfflineTtsMatchaModelConfig
    var kokoro: OfflineTtsKokoroModelConfig
    var kitten: OfflineTtsKittenModelConfig
    
    init() {
        vits = OfflineTtsVitsModelConfig()
        num_threads = 2
        debug = 0
        provider = nil
        matcha = OfflineTtsMatchaModelConfig()
        kokoro = OfflineTtsKokoroModelConfig()
        kitten = OfflineTtsKittenModelConfig()
    }
}

private struct OfflineTtsConfig {
    var model: OfflineTtsModelConfig
    var rule_fsts: UnsafeMutablePointer<CChar>?
    var max_num_sentences: Int32
    var rule_fars: UnsafeMutablePointer<CChar>?
    var silence_scale: Float
    
    init() {
        model = OfflineTtsModelConfig()
        rule_fsts = nil
        max_num_sentences = 2
        rule_fars = nil
        silence_scale = 0.3
    }
}
*/