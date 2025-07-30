import Foundation
import AppKit
import Carbon
import ApplicationServices

/// Core service for handling text insertion across different UI controls
class TextInsertionService {
    
    // MARK: - Shared Instance
    
    /// Shared singleton instance
    static let shared = TextInsertionService()
    
    // MARK: - Properties
    
    // Text tracking
    private var lastInsertedText: String = ""
    private var isNewRecordingSession: Bool = true
    private var streamingInsertionStart: Int = 0
    private var streamingInsertedLength: Int = 0
    private var streamingInsertedText: String = ""
    private var finalizedText: String = ""
    
    // Service dependencies
    private let textFormatter: TextFormatter
    private let repetitionHandler: RepetitionHandler
    private let directTextInsertion: DirectTextInsertion
    private let accessibilityTextInsertion: AccessibilityTextInsertion
    private let clipboardTextInsertion: ClipboardTextInsertion
    
    // Active UI elements
    private weak var activeTextField: NSTextField?
    private weak var activeTextView: NSTextView?
    
    // MARK: - Initialization
    
    init() {
        // Initialize service dependencies
        self.textFormatter = TextFormatter()
        self.directTextInsertion = DirectTextInsertion()
        self.clipboardTextInsertion = ClipboardTextInsertion()
        self.accessibilityTextInsertion = AccessibilityTextInsertion(
            directTextInsertion: directTextInsertion,
            clipboardTextInsertion: clipboardTextInsertion
        )
        self.repetitionHandler = RepetitionHandler(directTextInsertion: directTextInsertion, textFormatter: textFormatter)
    }
    
    // MARK: - Public API
    
    /// Register a text field to receive transcription text
    /// - Parameter textField: The text field to register
    func registerTextField(_ textField: NSTextField) {
        self.activeTextField = textField
        self.activeTextView = nil
        print("🔄 Registered text field for text insertion")
    }
    
    /// Register a text view to receive transcription text
    /// - Parameter textView: The text view to register
    func registerTextView(_ textView: NSTextView) {
        self.activeTextView = textView
        self.activeTextField = nil
        print("🔄 Registered text view for text insertion")
    }
    
    /// Unregister any active text components
    func unregisterTextComponents() {
        self.activeTextField = nil
        self.activeTextView = nil
        print("🔄 Unregistered all text components")
    }
    
    /// Handles a transcription result from speech recognition
    /// - Parameters:
    ///   - text: The transcribed text
    ///   - isFinal: Whether this is a finalized transcription
    ///   - language: The language of the transcription
    func handleTranscriptionResult(_ text: String, isFinal: Bool, language: String = "en") {
        print("\(isFinal ? "✅" : "🔄") \(isFinal ? "Final" : "Interim") transcription: \"\(text)\"")
        
        guard !text.isEmpty else {
            print("⚠️ Empty transcription, ignoring")
            return
        }
        
        if isFinal {
            print("✅ Processing final transcription: \"\(text)\"")
            
            // Check for severe repetition issues before inserting
            if repetitionHandler.detectAndFixProblematicPattern(
                activeTextField: activeTextField,
                activeTextView: activeTextView,
                finalizedText: finalizedText
            ) {
                print("🧹 Applied repetition fix")
            } else {
                // Format the text before insertion
                let formattedText = textFormatter.formatText(
                    text,
                    language: language,
                    lastInsertedText: lastInsertedText,
                    isNewRecordingSession: isNewRecordingSession,
                    onLastInsertedTextUpdated: { [weak self] updatedText in
                        self?.lastInsertedText = updatedText
                    }
                )
                
                if !formattedText.isEmpty {
                    // Try to replace temporary text with this final text first
                    if !streamingInsertedText.isEmpty {
                        print("🔄 Replacing temporary text: \"\(streamingInsertedText)\" with finalized: \"\(formattedText)\"")
                        replaceTemporaryText(streamingInsertedText, with: formattedText)
                    } else {
                        print("🔄 Inserting final text: \"\(formattedText)\"")
                        insertText(formattedText, isTemporary: false)
                    }
                }
            }
            
            // Reset streaming state
            streamingInsertedText = ""
            isNewRecordingSession = false
            
            // Reset segment tracking to avoid overlap issues between sessions
            textFormatter.resetSegmentTracking()
        } else {
            // For temporary transcription (streaming mode), accumulate the text
            print("🔄 Processing temporary transcription: \"\(text)\"")
            
            // Clean and check for overlapping text
            let cleanedText = textFormatter.cleanText(text)
            let nonOverlappingText = textFormatter.removeOverlappingText(cleanedText)
            
            if !nonOverlappingText.isEmpty {
                // If we have previous temporary text, replace it
                if !streamingInsertedText.isEmpty {
                    print("🔄 Replacing previous temporary text: \"\(streamingInsertedText)\" with: \"\(nonOverlappingText)\"")
                    replaceTemporaryText(streamingInsertedText, with: nonOverlappingText)
                } else {
                    print("🔄 Inserting temporary text: \"\(nonOverlappingText)\"")
                    insertText(nonOverlappingText, isTemporary: true)
                }
                
                // Update our tracking of the current streaming text
                streamingInsertedText = nonOverlappingText
            }
        }
    }
    
    /// Resets the text insertion state
    func resetTextInsertionState() {
        lastInsertedText = ""
        isNewRecordingSession = true
        streamingInsertionStart = 0
        streamingInsertedLength = 0
        streamingInsertedText = ""
        finalizedText = ""
        
        // Reset text segment tracking
        textFormatter.resetSegmentTracking()
        
        print("🧹 Reset all text insertion state")
    }
    
    /// Get the finalized text
    /// - Returns: The current finalized text
    func getFinalizedText() -> String {
        return finalizedText
    }
    
    /// Public method for inserting text with language parameter
    /// - Parameters:
    ///   - text: The text to insert
    ///   - language: The language of the text
    ///   - isTemporary: Whether this is temporary (streaming) text
    func insertText(_ text: String, language: String, isTemporary: Bool) {
        handleTranscriptionResult(text, isFinal: !isTemporary, language: language)
    }
    
    /// Alias for resetTextInsertionState, used by TranscriptionResultHandler
    func resetTextTrackingState() {
        resetTextInsertionState()
    }
    
    /// Reset text insertion state specifically for a new recording
    /// Called when a new recording session begins
    func resetForNewRecording() {
        // Reset all text tracking state
        resetTextInsertionState()
        
        // Set flag to indicate this is a new recording session
        isNewRecordingSession = true
        
        print("🎤 Reset text insertion state for new recording session")
    }
    
    /// Direct text insertion method for use with NSTextField
    /// - Parameters:
    ///   - text: The text to insert
    ///   - textField: The text field to insert into
    func insertTextDirectly(_ text: String, into textField: NSTextField) {
        // Register the text field as active
        registerTextField(textField)
        
        // Insert the text directly
        directTextInsertion.insertTextDirectly(
            text,
            into: textField,
            isTemporary: false,
            finalizedText: finalizedText,
            streamingInsertedText: streamingInsertedText,
            onFinalizedTextUpdated: { [weak self] updatedText in
                self?.finalizedText = updatedText
            },
            onStreamingStateUpdated: { [weak self] start, length in
                self?.streamingInsertionStart = start
                self?.streamingInsertedLength = length
            }
        )
    }
    
    // MARK: - Private Methods
    
    /// Replaces temporary text with finalized text
    /// - Parameters:
    ///   - temporaryText: The temporary text to replace
    ///   - finalText: The finalized text to insert
    private func replaceTemporaryText(_ temporaryText: String, with finalText: String) {
        // Add a space at the end of the final text to prevent connecting with next paste
        let finalTextWithSpace = finalText + " "
        
        print("🔄 Replacing temporary text: \"\(temporaryText)\" with \"\(finalTextWithSpace)\"")
        
        // Use text field if available
        if let textField = activeTextField {
            directTextInsertion.replaceTemporaryTextInTextField(
                temporaryText,
                with: finalTextWithSpace,
                in: textField,
                finalizedText: finalizedText,
                wouldCauseRepetition: { [weak self] currentText, newText in
                    guard let self = self else { return false }
                    return self.repetitionHandler.wouldCauseRepetition(currentText: currentText, newText: newText)
                },
                findDivergencePoint: { [weak self] oldText, newText in
                    guard let self = self else { return ("", newText) }
                    return self.textFormatter.findDivergencePoint(oldText, newText)
                },
                onFinalizedTextUpdated: { [weak self] updatedText in
                    self?.finalizedText = updatedText
                }
            )
            return
        }
        
        // Use text view if available
        if let textView = activeTextView {
            directTextInsertion.replaceTemporaryTextInTextView(
                temporaryText,
                with: finalTextWithSpace,
                in: textView,
                finalizedText: finalizedText,
                wouldCauseRepetition: { [weak self] currentText, newText in
                    guard let self = self else { return false }
                    return self.repetitionHandler.wouldCauseRepetition(currentText: currentText, newText: newText)
                },
                findDivergencePoint: { [weak self] oldText, newText in
                    guard let self = self else { return ("", newText) }
                    return self.textFormatter.findDivergencePoint(oldText, newText)
                },
                onFinalizedTextUpdated: { [weak self] updatedText in
                    self?.finalizedText = updatedText
                }
            )
            return
        }
        
        // Try accessibility API as fallback
        let _ = accessibilityTextInsertion.replaceTemporaryText(
            temporaryText,
            with: finalTextWithSpace,
            finalizedText: finalizedText,
            onFinalizedTextUpdated: { [weak self] updatedText in
                self?.finalizedText = updatedText
            }
        )
    }
    
    /// Inserts text using the appropriate method
    /// - Parameters:
    ///   - text: The text to insert
    ///   - isTemporary: Whether this is temporary (streaming) text
    private func insertText(_ text: String, isTemporary: Bool = false) {
        // If this is final text (not temporary), append a space to prevent connecting with next paste
        let textToInsert = isTemporary ? text : text + " "
        
        print("🔄 Inserting \(isTemporary ? "temporary" : "final") text: \"\(textToInsert)\"")
        
        // Use text field if available
        if let textField = activeTextField {
            directTextInsertion.insertTextDirectly(
                textToInsert,
                into: textField,
                isTemporary: isTemporary,
                finalizedText: finalizedText,
                streamingInsertedText: streamingInsertedText,
                onFinalizedTextUpdated: { [weak self] updatedText in
                    self?.finalizedText = updatedText
                },
                onStreamingStateUpdated: { [weak self] start, length in
                    self?.streamingInsertionStart = start
                    self?.streamingInsertedLength = length
                }
            )
            return
        }
        
        // Use text view if available
        if let textView = activeTextView {
            directTextInsertion.insertTextDirectly(
                textToInsert,
                into: textView,
                isTemporary: isTemporary,
                finalizedText: finalizedText,
                streamingInsertedText: streamingInsertedText,
                onFinalizedTextUpdated: { [weak self] updatedText in
                    self?.finalizedText = updatedText
                },
                onStreamingStateUpdated: { [weak self] start, length in
                    self?.streamingInsertionStart = start
                    self?.streamingInsertedLength = length
                }
            )
            return
        }
        
        // Try accessibility API as fallback
        let _ = accessibilityTextInsertion.insertText(
            textToInsert,
            isTemporary: isTemporary,
            finalizedText: finalizedText,
            streamingInsertedText: streamingInsertedText,
            onFinalizedTextUpdated: { [weak self] updatedText in
                self?.finalizedText = updatedText
            },
            onStreamingStateUpdated: { [weak self] start, length in
                self?.streamingInsertionStart = start
                self?.streamingInsertedLength = length
            }
        )
    }
    
    /// Tries all available text insertion methods using clipboard or key simulation
    /// - Parameters:
    ///   - text: The text to insert
    ///   - isTemporary: Whether this is a temporary transcription
    ///   - finalizedText: The finalized text to preserve
    ///   - streamingInsertedText: Currently streaming text being inserted
    ///   - onFinalizedTextUpdated: Callback to update finalized text
    ///   - onStreamingStateUpdated: Callback to update streaming state
    /// - Returns: Whether the insertion was successful
    private func tryAllTextInsertionMethods(
        _ text: String,
        isTemporary: Bool,
        finalizedText: String,
        streamingInsertedText: String,
        onFinalizedTextUpdated: @escaping (String) -> Void,
        onStreamingStateUpdated: @escaping (Int, Int) -> Void
    ) -> Bool {
        print("📋 Attempting to insert text via clipboard operation")
        
        // If this is final text (not temporary), append a space to prevent connecting with next paste
        let textToInsert = isTemporary ? text : text + " "
        
        // Fallback method: Use the clipboard operation which is faster and more reliable
        // than simulating keystrokes character by character
        let success = clipboardTextInsertion.insertText(textToInsert, preserveClipboard: true)
        
        // Update tracking data if successful
        if success && !isTemporary {
            var updatedFinalizedText = finalizedText
            if finalizedText.isEmpty {
                updatedFinalizedText = text // Don't include space when it's the first text
            } else {
                // Since we're already adding a space at the end of textToInsert, don't add another one
                updatedFinalizedText += textToInsert
            }
            onFinalizedTextUpdated(updatedFinalizedText)
            print("🔄 Updated finalized text: \"\(updatedFinalizedText)\"")
        }
        
        if success {
            print("✅ Successfully inserted text via clipboard operation")
            return true
        }
        
        print("⚠️ All text insertion methods failed")
        return false
    }
}

// Extension to add accessibility functionality to NSRunningApplication
extension NSRunningApplication {
    func focusedUIElement() -> AXUIElement? {
        let appRef = AXUIElementCreateApplication(processIdentifier)
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success, let element = focusedElement {
            return (element as! AXUIElement)
        }
        
        return nil
    }
} 