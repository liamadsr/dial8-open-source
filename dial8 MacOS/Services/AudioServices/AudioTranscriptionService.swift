import Foundation
import AVFoundation
import Combine
import SwiftUI

class AudioTranscriptionService: ObservableObject {
    // Singleton instance
    static let shared = AudioTranscriptionService()
    
    // Published properties
    @Published var useLocalWhisperModel = true
    @Published var whisperModelIsReady: Bool = false
    @Published private(set) var accumulatedText: String = ""
    @Published private(set) var isProcessingSpeech = false
    
    // Dependencies
    private let whisperManager = WhisperManager.shared
    
    // Current language selection
    private var selectedLanguage: String = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "english"
    
    private init() {
        // Force useLocalWhisperModel to always be true
        self.useLocalWhisperModel = true
        UserDefaults.standard.set(true, forKey: "useLocalWhisperModel")
        
        // Start the setup of WhisperManager
        WhisperManager.shared.startSetup()
        
        // Observe changes to the 'useLocalWhisperModel' key in UserDefaults
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDefaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // Add observer for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChanged),
            name: NSNotification.Name("SelectedLanguageChanged"),
            object: nil
        )
        
        // Observe WhisperManager's isReady property
        WhisperManager.shared.$isReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$whisperModelIsReady)
    }
    
    @objc private func handleUserDefaultsChanged(_ notification: Notification) {
        let newValue = UserDefaults.standard.bool(forKey: "useLocalWhisperModel")
        if newValue != self.useLocalWhisperModel {
            self.useLocalWhisperModel = newValue
            
            if newValue {
                // Start setup of WhisperManager
                WhisperManager.shared.startSetup()
            } else {
                // If local model is disabled, set isReady to false
                WhisperManager.shared.isReady = false
            }
        }
    }
    
    @objc private func handleLanguageChanged(_ notification: Notification) {
        if let language = notification.userInfo?["language"] as? String {
            selectedLanguage = language
            print("Language changed to: \(language)")
        }
    }
    
    // This method will now be called by AudioProcessingQueueService
    func addToProcessingQueue(audioURL: URL, timestamp: Date) {
        // This is now implemented in AudioProcessingQueueService
        // When AudioManager calls this, it should be redirected to AudioProcessingQueueService
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioSegmentReadyForProcessing"),
            object: nil,
            userInfo: ["audioURL": audioURL, "timestamp": timestamp]
        )
    }
    
    func handleTranscriptionResult(_ transcription: String, recordingStartTime: Date?, isTemporary: Bool = false) {
        print("🔴 AudioTranscriptionService.handleTranscriptionResult called with: \"\(transcription)\"")
        
        DispatchQueue.main.async {
            // If this is temporary accumulated text, store it locally
            if isTemporary {
                self.accumulatedText = transcription
            } else {
                // Otherwise forward to the result handler
                print("🔴 AudioTranscriptionService: Forwarding transcription to TranscriptionResultHandler")
                
                // Forward to TranscriptionResultHandler with the start time
                TranscriptionResultHandler.shared.handleTranscriptionResult(
                    transcription,
                    recordingStartTime: recordingStartTime,
                    isTemporary: false
                )
                
                // Don't clear accumulated text here - let AudioManager manage it
                // self.accumulatedText = ""
                
                print("🔴 AudioTranscriptionService: Successfully forwarded transcription")
            }
        }
    }
    
    func processCurrentAudioFile(at fileURL: URL, mode: RecordingMode) {
        let audioFileURL = fileURL
        
        print("Processing audio file...")
        if useLocalWhisperModel && WhisperManager.shared.isReady {
            // Use local transcription with selected language
            let targetLanguage: String = selectedLanguage

            WhisperManager.shared.transcribe(audioURL: audioFileURL, mode: mode, targetLanguage: targetLanguage) { [weak self] result in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let transcription):
                        self.handleTranscriptionResult(transcription, recordingStartTime: Date())
                    case .failure(let error):
                        print("Transcription error: \(error)")
                    }
                    // Clean up the processed file
                    try? FileManager.default.removeItem(at: audioFileURL)
                }
            }
        } else {
            // Use server-based transcription - implementation details moved to AudioProcessingQueueService
            sendAudioToBackend(fileURL: audioFileURL) {
                try? FileManager.default.removeItem(at: audioFileURL)
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

        URLSession.shared.uploadTask(with: request, from: data) { data, response, error in
            if let error = error {
                print("Error sending audio: \(error)")
                completion()
                return
            }

            if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let transcription = TranscriptionUtils.extractTranscription(from: jsonString)
                    print("Transcription received: \(transcription)")

                    self.handleTranscriptionResult(transcription, recordingStartTime: Date())
                }
            }

            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
    
    func clearAccumulatedText() {
        DispatchQueue.main.async {
            // Simply set the text to empty without animation
            self.accumulatedText = ""
        }
    }
    
    func updateAccumulatedText(_ text: String) {
        DispatchQueue.main.async {
            self.accumulatedText = text
        }
    }
} 