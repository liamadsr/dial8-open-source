import Foundation
import AVFoundation
import Combine

class AudioRecordingService: ObservableObject {
    // Published properties for state
    @Published private(set) var isRecording = false
    @Published private(set) var isStoppingRecording = false
    @Published var recordingStartTime: Date?
    
    // Audio recording components
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    
    // Dependencies
    private let audioEngineService: AudioEngineService
    
    init(audioEngineService: AudioEngineService) {
        self.audioEngineService = audioEngineService
    }
    
    func beginRecording() {
        print("AudioRecordingService: Beginning recording with streaming functionality")
        
        // Initialize recording start time
        self.recordingStartTime = Date()
        print("⏱️ Recording start time initialized")
        
        let tempDir = FileManager.default.temporaryDirectory
        self.audioFileURL = tempDir.appendingPathComponent("recording_\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,  // Direct Whisper input - must be 16kHz
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            self.audioRecorder = try AVAudioRecorder(url: self.audioFileURL!, settings: settings)
            self.audioRecorder?.record()
            self.isRecording = true
            print("Recording started successfully with streaming functionality")
        } catch {
            print("Failed to start recording: \(error)")
            DispatchQueue.main.async {
                self.isRecording = false
            }
        }
    }
    
    func stopRecording(withFinalProcessing: Bool = true, completion: @escaping (URL?) -> Void) {
        guard isRecording else { 
            completion(nil)
            return 
        }
        
        print("⏹️ Stopping recording...")
        
        // Set the stopping flag immediately to prevent new speech detection events
        self.isStoppingRecording = true
        
        // Immediately update recording state
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Use a slightly longer fixed delay to ensure we capture trailing audio
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { 
                completion(nil)
                return 
            }
            
            // Increased delay to ensure audioRecorder captures final audio
            Thread.sleep(forTimeInterval: 0.3)
            
            // Stop the audio recorder
            self.audioRecorder?.stop()
            self.audioRecorder = nil
            
            let fileURL = self.audioFileURL
            
            // Reset state
            self.isStoppingRecording = false
            self.audioFileURL = nil
            
            // Return the file URL for processing if needed
            completion(withFinalProcessing ? fileURL : nil)
            
            // If not processing the file, clean it up
            if !withFinalProcessing, let fileURL = fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    func startNewAudioSegment() -> URL? {
        print("Starting new audio segment...")
        
        // Create new audio file URL
        let tempDir = FileManager.default.temporaryDirectory
        let newAudioFileURL = tempDir.appendingPathComponent("recording_\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,  // Direct Whisper input - must be 16kHz
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            // Create new recorder
            let newRecorder = try AVAudioRecorder(url: newAudioFileURL, settings: settings)
            
            // Start new recording before stopping the old one to minimize gaps
            newRecorder.record()
            print("Started new recording - minimizing transition gap")
            
            // Capture current references before replacing them
            let oldRecorder = audioRecorder
            let oldFileURL = audioFileURL
            
            // Update references immediately to minimize potential race conditions
            audioRecorder = newRecorder
            audioFileURL = newAudioFileURL
            recordingStartTime = Date()
            
            // Now stop the old recorder if it exists
            if let currentRecorder = oldRecorder {
                // Use a very small delay to ensure the new recording is running
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.01) {
                    currentRecorder.stop()
                    print("Stopped previous audio segment recording")
                }
            }
            
            print("Started new audio segment recording seamlessly")
            
            // Check if audio engine needs reconfiguration
            if audioEngineService.engineState == .inactive {
                print("Audio engine inactive, reconfiguring...")
            }
            
            return oldFileURL
        } catch {
            print("Failed to start new audio segment: \(error)")
            return nil
        }
    }
    
    func cleanupTempFile(at url: URL?) {
        guard let url = url else { return }
        
        do {
            try FileManager.default.removeItem(at: url)
            print("Cleaned up temporary audio file at: \(url.lastPathComponent)")
        } catch {
            print("Failed to clean up temporary file: \(error)")
        }
    }
} 