import Foundation

class TranscriptionResultHandler {
    static let shared = TranscriptionResultHandler()
    
    
    // Block mode text accumulation
    private var accumulatedText: String = ""
    private var isBlockMode: Bool = false
    
    private init() {}
    
    private let queue = DispatchQueue(label: "com.dial8.transcriptionHandler")
    
    
    /// Set block mode state
    func setBlockMode(_ blockMode: Bool) {
        isBlockMode = blockMode
        print("📝 TranscriptionResultHandler: Block mode set to \(blockMode)")
        
        // Clear accumulated text when switching modes
        if !blockMode && !accumulatedText.isEmpty {
            // If switching from block to streaming mode, insert accumulated text
            insertAccumulatedText(accumulatedText)
            accumulatedText = ""
        }
    }
    
    /// Get current accumulated text (for block mode)
    func getAccumulatedText() -> String {
        return accumulatedText
    }
    
    /// Clear accumulated text
    func clearAccumulatedText() {
        accumulatedText = ""
        print("📝 TranscriptionResultHandler: Cleared accumulated text")
    }
    
    /// Insert accumulated text and clear buffer
    func flushAccumulatedText() {
        if !accumulatedText.isEmpty {
            // Clean the accumulated text before inserting
            Task {
                await cleanAndInsertAccumulatedText()
            }
        }
    }
    
    /// Clean text using Foundation Models and insert it (for streaming mode)
    private func cleanAndInsertText(_ text: String, isTemporary: Bool) async {
        // Check if cleaning is enabled in settings
        let cleaningEnabled = UserDefaults.standard.bool(forKey: "enableTranscriptionCleaning")
        
        if cleaningEnabled && TranscriptionCleaner.shared.isAvailable() && !text.isEmpty {
            do {
                print("🧹 TranscriptionResultHandler: Cleaning streaming text...")
                print("📝 Original text: \"\(text)\"")
                let cleanedText = try await TranscriptionCleaner.shared.cleanTranscription(text)
                print("✨ Cleaned text: \"\(cleanedText)\"")
                print("✅ TranscriptionResultHandler: Text cleaned successfully")
                
                await MainActor.run {
                    // Apply text replacements after AI cleaning but before insertion
                    let processedText = TextReplacementService.shared.applyReplacements(to: cleanedText)
                    self.handleTranscriptionInsertion(processedText, isTemporary: isTemporary)
                }
            } catch {
                print("⚠️ TranscriptionResultHandler: Cleaning failed, using original text")
                await MainActor.run {
                    // Apply text replacements even when cleaning fails
                    let processedText = TextReplacementService.shared.applyReplacements(to: text)
                    self.handleTranscriptionInsertion(processedText, isTemporary: isTemporary)
                }
            }
        } else {
            // If cleaning is disabled or unavailable, use original text
            await MainActor.run {
                // Apply text replacements when cleaning is disabled
                let processedText = TextReplacementService.shared.applyReplacements(to: text)
                self.handleTranscriptionInsertion(processedText, isTemporary: isTemporary)
            }
        }
    }
    
    /// Clean accumulated text using Foundation Models and insert it
    private func cleanAndInsertAccumulatedText() async {
        let textToClean = accumulatedText
        accumulatedText = ""
        
        // Check if cleaning is enabled in settings
        let cleaningEnabled = UserDefaults.standard.bool(forKey: "enableTranscriptionCleaning")
        
        if cleaningEnabled && TranscriptionCleaner.shared.isAvailable() {
            do {
                print("🧹 TranscriptionResultHandler: Cleaning accumulated text...")
                print("📝 Original text: \"\(textToClean)\"")
                let cleanedText = try await TranscriptionCleaner.shared.cleanTranscription(textToClean)
                print("✨ Cleaned text: \"\(cleanedText)\"")
                print("✅ TranscriptionResultHandler: Text cleaned successfully")
                
                await MainActor.run {
                    // Apply text replacements after AI cleaning but before insertion
                    let processedText = TextReplacementService.shared.applyReplacements(to: cleanedText)
                    self.insertAccumulatedText(processedText)
                }
            } catch {
                print("⚠️ TranscriptionResultHandler: Cleaning failed, using original text")
                await MainActor.run {
                    // Apply text replacements even when cleaning fails
                    let processedText = TextReplacementService.shared.applyReplacements(to: textToClean)
                    self.insertAccumulatedText(processedText)
                }
            }
        } else {
            // If cleaning is disabled or unavailable, use original text
            await MainActor.run {
                // Apply text replacements when cleaning is disabled
                let processedText = TextReplacementService.shared.applyReplacements(to: textToClean)
                self.insertAccumulatedText(processedText)
            }
        }
        
        print("📝 TranscriptionResultHandler: Flushed accumulated text")
    }
    
    /// Handles transcription for streaming mode
    /// - Parameters:
    ///   - transcription: The transcription text
    ///   - recordingStartTime: When the recording started
    ///   - isTemporary: Whether this is a temporary transcription that might be replaced
    func handleTranscriptionResult(_ transcription: String, recordingStartTime: Date?, isTemporary: Bool = false) {
        print("🔤 TranscriptionResultHandler: Processing \(isTemporary ? "temporary" : "final") text: \"\(transcription)\"")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Handle text insertion based on mode
            if self.isBlockMode && !isTemporary {
                    // In block mode, accumulate final text instead of inserting immediately
                    let textToAdd = transcription
                    if self.accumulatedText.isEmpty {
                        self.accumulatedText = textToAdd
                    } else {
                        self.accumulatedText += " " + textToAdd
                    }
                    print("📝 TranscriptionResultHandler: Accumulated text in block mode: \"\(self.accumulatedText)\"")
                } else if !self.isBlockMode {
                    // In streaming mode, clean and insert text
                    if !isTemporary {
                        // For final text in streaming mode, apply cleaning
                        Task {
                            await self.cleanAndInsertText(transcription, isTemporary: false)
                        }
                    } else {
                        // For temporary text, insert without cleaning to maintain responsiveness
                        DispatchQueue.main.async {
                            print("📲 TranscriptionResultHandler: Inserting temporary text: \"\(transcription)\"")
                            // Apply text replacements to temporary text for immediate feedback
                            let processedText = TextReplacementService.shared.applyReplacements(to: transcription)
                            self.handleTranscriptionInsertion(processedText, isTemporary: true)
                        }
                    }
                }
                // In block mode, ignore temporary transcriptions (don't show them)
        }
    }
    
    /// Handles final text insertion without counting words - needed for backward compatibility
    func insertAccumulatedText(_ text: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.handleTranscriptionInsertion(text, isTemporary: false)
            }
            
            self.resetSession()
        }
    }
    
    
    /// Helper method to handle text insertion
    private func handleTranscriptionInsertion(_ text: String, isTemporary: Bool = false) {
        print("📝 Inserting \(isTemporary ? "temporary" : "final") text: \"\(text)\"")
        
        // Get the current language from UserDefaults
        let language = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "auto"

        // Use the TextInsertionService to insert the text
        print("🔤 Calling TextInsertionService to insert \(isTemporary ? "temporary" : "final") text with language: \(language)")
        TextInsertionService.shared.insertText(text, language: language, isTemporary: isTemporary)
        
        // Add to history if it's final text (not temporary)
        if !isTemporary && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            TranscriptionHistoryManager.shared.addTranscription(text)
        }

        // Word counting removed - no longer tracking usage
    }
    
    /// Reset the current speech session
    func resetSession() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Reset the text tracking state in TextInsertionService
            DispatchQueue.main.async {
                TextInsertionService.shared.resetTextTrackingState()
            }
        }
    }
    
    /// Called when silence is detected
    func handleSilenceDetected() {
        resetSession()
    }
} 