import Foundation
import AVFoundation
import Combine

class AudioProcessingQueueService: ObservableObject {
    // Processing queue for audio segments
    private var processingQueue: [(URL, Date)] = []
    private var isCurrentlyProcessing = false
    
    // Throttling for audio processing
    private var lastProcessingTime: Date?
    private let processingThrottle: TimeInterval = 0.1
    
    // Dependencies
    private let audioTranscriptionService: AudioTranscriptionService
    private let whisperManager: WhisperManager
    
    // State
    @Published private(set) var queueLength: Int = 0
    
    init(audioTranscriptionService: AudioTranscriptionService, whisperManager: WhisperManager = WhisperManager.shared) {
        self.audioTranscriptionService = audioTranscriptionService
        self.whisperManager = whisperManager
        
        // Set up notification observer for audio segments ready for processing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSegmentReady),
            name: NSNotification.Name("AudioSegmentReadyForProcessing"),
            object: nil
        )
    }
    
    @objc private func handleAudioSegmentReady(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let audioURL = userInfo["audioURL"] as? URL,
              let timestamp = userInfo["timestamp"] as? Date else {
            print("Error: Invalid notification data for audio segment processing")
            return
        }
        
        addToProcessingQueue(audioURL: audioURL, timestamp: timestamp)
    }
    
    func addToProcessingQueue(audioURL: URL, timestamp: Date) {
        DispatchQueue.main.async {
            self.processingQueue.append((audioURL, timestamp))
            self.queueLength = self.processingQueue.count
            self.processNextInQueue()
        }
    }
    
    func processNextInQueue() {
        // If already processing or queue is empty, return
        guard !isCurrentlyProcessing, !processingQueue.isEmpty else { return }
        
        // Mark as processing
        isCurrentlyProcessing = true
        
        // Get next item to process
        let (audioURL, timestamp) = processingQueue.removeFirst()
        queueLength = processingQueue.count
        
        print("🎯 Processing queued audio segment...")
        
        // Use high-priority queue for transcription
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let useLocalWhisperModel = self.audioTranscriptionService.useLocalWhisperModel
            
            if useLocalWhisperModel && self.whisperManager.isReady {
                self.processWithWhisper(audioURL: audioURL, timestamp: timestamp)
            } else {
                self.sendAudioToBackend(fileURL: audioURL) {
                    // Clean up immediately
                    try? FileManager.default.removeItem(at: audioURL)
                    
                    DispatchQueue.main.async {
                        self.isCurrentlyProcessing = false
                        self.processNextInQueue()
                    }
                }
            }
        }
    }
    
    private func processWithWhisper(audioURL: URL, timestamp: Date) {
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "english"
        
        whisperManager.transcribe(
            audioURL: audioURL,
            mode: .transcriptionOnly,
            targetLanguage: selectedLanguage
        ) { [weak self] result in
            guard let self = self else { return }
            
            // Clean up immediately after getting result
            try? FileManager.default.removeItem(at: audioURL)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    self.audioTranscriptionService.handleTranscriptionResult(transcription, recordingStartTime: timestamp)
                case .failure(let error):
                    print("Transcription error: \(error)")
                }
                
                // Mark as done and process next
                self.isCurrentlyProcessing = false
                self.processNextInQueue()
            }
        }
    }
    
    private func sendAudioToBackend(fileURL: URL, completion: @escaping () -> Void) {
        let url = URL(string: "http://localhost:8180/stt")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(AppConfig.API_KEY, forHTTPHeaderField: "X-API-Key")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()
        data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)

        do {
            let audioData = try Data(contentsOf: fileURL)
            data.append(audioData)
        } catch {
            print("Error reading audio file: \(error)")
            completion()
            return
        }

        data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: data) { [weak self] data, response, error in
            guard let self = self else { 
                completion()
                return 
            }
            
            if let error = error {
                print("Error sending audio: \(error)")
                completion()
                return
            }

            if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let transcription = TranscriptionUtils.extractTranscription(from: jsonString)
                    print("Transcription received: \(transcription)")

                    self.audioTranscriptionService.handleTranscriptionResult(transcription, recordingStartTime: Date())
                }
            }

            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 
