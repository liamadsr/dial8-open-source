import Foundation
import Combine
import AVFoundation

class AudioSegmentationService: ObservableObject {
    // Dependencies
    private let recordingService: AudioRecordingService
    private let audioTranscriptionService: AudioTranscriptionService
    
    // State
    private var isStoppingRecording = false
    
    init(recordingService: AudioRecordingService, audioTranscriptionService: AudioTranscriptionService) {
        self.recordingService = recordingService
        self.audioTranscriptionService = audioTranscriptionService
    }
    
    // Handle silence detection to create a new segment
    func handleSilenceDetected(isRecording: Bool, isStoppingRecording: Bool, lastSpeechTime: Date?, isStreamingMode: Bool = true) {
        // In block mode, don't create segments on silence detection
        // Just continue recording as one continuous file
        guard isStreamingMode else { 
            print("Block mode: Ignoring silence detection, continuing single recording")
            return 
        }
        
        // In streaming mode, process segments on silence detection
        guard isRecording && !isStoppingRecording else { return }
        
        if let startTime = lastSpeechTime {
            // Process audio segment when silence is detected
            if let oldFileURL = recordingService.startNewAudioSegment() {
                // Play ready sound to indicate processing
                HUDSoundEffects.shared.playReadySound()
                
                // Process the completed segment
                Task { @MainActor in
                    // Minimal delay to ensure file is fully written
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
                    
                    // Add segment to processing queue
                    audioTranscriptionService.addToProcessingQueue(audioURL: oldFileURL, timestamp: startTime)
                }
            }
        }
    }
    
    // Handle final segment when stopping recording
    func handleFinalSegment(fileURL: URL?, hasSpeechBeenDetectedRecently: Bool, mode: RecordingMode) {
        if let fileURL = fileURL, hasSpeechBeenDetectedRecently {
            // Process the final audio segment
            audioTranscriptionService.processCurrentAudioFile(at: fileURL, mode: mode)
        }
    }
    
    // Handle accumulated text when stopping recording without a final segment
    func handleAccumulatedText(isStreamingMode: Bool, lastSpeechTime: Date?) {
        if isStreamingMode && !audioTranscriptionService.accumulatedText.isEmpty {
            TranscriptionResultHandler.shared.handleTranscriptionResult(
                audioTranscriptionService.accumulatedText,
                recordingStartTime: lastSpeechTime
            )
            audioTranscriptionService.clearAccumulatedText()
        }
    }
} 
