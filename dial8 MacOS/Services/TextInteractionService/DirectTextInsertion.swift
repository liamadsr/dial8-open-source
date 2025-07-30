import Foundation
import AppKit

/// Responsible for directly inserting text into UI controls
class DirectTextInsertion {
    
    init() {}
    
    /// Completely resets the text field when severe repetition is detected
    /// - Parameters:
    ///   - finalText: The final text to insert after resetting
    ///   - activeTextField: The active text field
    ///   - activeTextView: The active text view
    ///   - finalizedText: The finalized text to preserve
    ///   - onFinalizedTextUpdated: Callback to update finalized text
    /// - Returns: True if the reset was successful
    func resetTextFieldAndInsertFinalText(
        _ finalText: String,
        activeTextField: NSTextField?,
        activeTextView: NSTextView?,
        finalizedText: String,
        onFinalizedTextUpdated: @escaping (String) -> Void
    ) -> Bool {
        print("🧹 Completely resetting text field due to severe repetition")
        
        // Create the text to insert - preserve finalized text if it exists
        var textToInsert = finalText
        if !finalizedText.isEmpty {
            print("🔄 Preserving existing finalized text: \"\(finalizedText)\"")
            // Check if finalText is already part of finalizedText to avoid duplication
            if !finalizedText.contains(finalText) {
                textToInsert = finalizedText + (finalizedText.isEmpty ? "" : " ") + finalText
            } else {
                textToInsert = finalizedText
            }
        }
        
        // Update our finalized text tracking
        onFinalizedTextUpdated(textToInsert)
        print("🔄 Updated finalized text: \"\(textToInsert)\"")
        
        // Apply the reset
        if let textField = activeTextField {
            print("🔄 Resetting text field with: \"\(textToInsert)\"")
            textField.stringValue = textToInsert
            textField.sendAction(textField.action, to: textField.target)
            return true
        } else if let textView = activeTextView {
            print("🔄 Resetting text view with: \"\(textToInsert)\"")
            textView.string = textToInsert
            return true
        } else if let focusedElement = NSWorkspace.shared.frontmostApplication?.focusedUIElement() {
            // Try to use accessibility API
            print("🔄 Resetting using accessibility API with: \"\(textToInsert)\"")
            let result = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, textToInsert as CFTypeRef)
            return result == .success
        }
        
        return false
    }
    
    /// Inserts text in a text field while preserving finalized text
    /// - Parameters:
    ///   - text: The text to insert
    ///   - textField: The text field to insert into
    ///   - currentText: The current text in the text field
    ///   - finalizedText: The finalized text to preserve
    func insertTextInTextField(
        _ text: String,
        into textField: NSTextField,
        currentText: String,
        finalizedText: String
    ) {
        // If we have finalized text, we need to ensure we only append to it
        if currentText.hasPrefix(finalizedText) {
            // The current text starts with our finalized text - just append new text
            let newText = currentText + (currentText.isEmpty ? "" : " ") + text
            textField.stringValue = newText
        } else {
            // The current text doesn't contain our finalized text - try to preserve both
            let space = currentText.isEmpty ? "" : " "
            let newText = !currentText.isEmpty ? currentText + space + text : text
            textField.stringValue = newText
        }
        textField.sendAction(textField.action, to: textField.target)
    }
    
    /// Inserts text in a text view while preserving finalized text
    /// - Parameters:
    ///   - text: The text to insert
    ///   - textView: The text view to insert into
    ///   - currentText: The current text in the text view
    ///   - finalizedText: The finalized text to preserve
    ///   - wouldCauseRepetition: Function to check if insertion would cause repetition
    func insertTextInTextView(
        _ text: String,
        into textView: NSTextView,
        currentText: String,
        finalizedText: String,
        wouldCauseRepetition: (String, String) -> Bool
    ) {
        // If we have finalized text, we need to ensure we only append to it
        if currentText.hasPrefix(finalizedText) {
            // The current text starts with our finalized text - just append new text
            let insertionPoint = NSRange(location: currentText.count, length: 0)
            textView.insertText(" " + text, replacementRange: insertionPoint)
        } else {
            // The current text doesn't contain our finalized text - try to preserve both
            let space = currentText.isEmpty ? "" : " "
            let potentialNewText = currentText + space + text
            
            if wouldCauseRepetition(currentText, potentialNewText) {
                // If appending would cause repetition, try resetting with just the finalized text
                textView.string = finalizedText + " " + text
            } else {
                // Otherwise append normally
                let insertionPoint = NSRange(location: currentText.count, length: 0)
                textView.insertText(space + text, replacementRange: insertionPoint)
            }
        }
    }
    
    /// Directly sets text on a text field
    /// - Parameters:
    ///   - text: The text to insert
    ///   - textField: The text field to insert into
    ///   - isTemporary: Whether this is a temporary transcription
    ///   - finalizedText: The finalized text to preserve
    ///   - streamingInsertedText: Currently streaming text being inserted
    ///   - onFinalizedTextUpdated: Callback to update finalized text
    ///   - onStreamingStateUpdated: Callback to update streaming state
    func insertTextDirectly(
        _ text: String,
        into textField: NSTextField,
        isTemporary: Bool = false,
        finalizedText: String,
        streamingInsertedText: String,
        onFinalizedTextUpdated: @escaping (String) -> Void,
        onStreamingStateUpdated: @escaping (Int, Int) -> Void
    ) {
        DispatchQueue.main.async {
            let currentText = textField.stringValue
            let currentLength = currentText.count
            
            if isTemporary {
                // Store the position where we're inserting
                onStreamingStateUpdated(currentLength, text.count)
                
                // If we have finalized text, make sure it's preserved
                if !finalizedText.isEmpty && currentText.hasPrefix(finalizedText) {
                    // Only append the temporary text to the finalized text
                    let space = finalizedText.isEmpty ? "" : " "
                    textField.stringValue = finalizedText + space + text
                    print("🔄 Preserved finalized text and appended temporary text")
                } else {
                    // Normal insertion
                    let space = currentText.isEmpty ? "" : " "
                    textField.stringValue = currentText + space + text
                }
            } else {
                // For final text, update our tracking
                var updatedFinalizedText = finalizedText
                
                if finalizedText.isEmpty {
                    updatedFinalizedText = text
                    onFinalizedTextUpdated(updatedFinalizedText)
                    
                    // Normal insertion
                    let space = currentText.isEmpty ? "" : " "
                    textField.stringValue = currentText + space + text
                } else {
                    // Check if the current text starts with our finalized text
                    if currentText.hasPrefix(finalizedText) {
                        // Append to existing finalized text with a space
                        updatedFinalizedText += " " + text
                        onFinalizedTextUpdated(updatedFinalizedText)
                        
                        // Replace any temporary text after the finalized text
                        if !streamingInsertedText.isEmpty {
                            if let range = currentText.range(of: streamingInsertedText, options: [], range: currentText.index(currentText.startIndex, offsetBy: finalizedText.count - text.count)..<currentText.endIndex) {
                                // Replace the temporary text
                                var newText = currentText
                                newText.replaceSubrange(range, with: text)
                                textField.stringValue = newText
                            } else {
                                // If we can't find the temporary text, just append
                                let space = currentText.isEmpty ? "" : " "
                                textField.stringValue = currentText + space + text
                            }
                        } else {
                            // Just append if no temporary text
                            let space = currentText.isEmpty ? "" : " "
                            textField.stringValue = currentText + space + text
                        }
                    } else {
                        // The current text doesn't contain our finalized text
                        // Append the new text to our finalized text tracking
                        updatedFinalizedText += " " + text
                        onFinalizedTextUpdated(updatedFinalizedText)
                        
                        // Try to preserve both the current text and our finalized text
                        let space = currentText.isEmpty ? "" : " "
                        let newText = !currentText.isEmpty ? currentText + space + text : text
                        textField.stringValue = newText
                    }
                }
                print("🔄 Updated finalized text: \"\(updatedFinalizedText)\"")
            }
            
            // Notify that the text changed
            textField.sendAction(textField.action, to: textField.target)
        }
    }
    
    /// Directly sets text on a text view
    /// - Parameters:
    ///   - text: The text to insert
    ///   - textView: The text view to insert into
    ///   - isTemporary: Whether this is a temporary transcription
    ///   - finalizedText: The finalized text to preserve
    ///   - streamingInsertedText: Currently streaming text being inserted
    ///   - onFinalizedTextUpdated: Callback to update finalized text
    ///   - onStreamingStateUpdated: Callback to update streaming state
    func insertTextDirectly(
        _ text: String,
        into textView: NSTextView,
        isTemporary: Bool = false,
        finalizedText: String,
        streamingInsertedText: String,
        onFinalizedTextUpdated: @escaping (String) -> Void,
        onStreamingStateUpdated: @escaping (Int, Int) -> Void
    ) {
        DispatchQueue.main.async {
            let selectedRange = textView.selectedRange()
            let currentText = textView.string
            
            // Determine if we need to add a space before the new text
            let needsLeadingSpace = selectedRange.location > 0 &&
                !currentText[currentText.index(currentText.startIndex, offsetBy: selectedRange.location - 1)].isWhitespace
            
            let textToInsert = (needsLeadingSpace ? " " : "") + text
            
            if isTemporary {
                // Store the position where we're inserting
                onStreamingStateUpdated(selectedRange.location, textToInsert.count)
                
                // If we have finalized text, make sure it's preserved
                if !finalizedText.isEmpty && currentText.hasPrefix(finalizedText) {
                    // Only append the temporary text to the finalized text
                    let insertionPoint = NSRange(location: finalizedText.count + (needsLeadingSpace ? 1 : 0), length: 0)
                    textView.insertText(textToInsert, replacementRange: insertionPoint)
                    print("🔄 Preserved finalized text and appended temporary text")
                } else {
                    // Normal insertion
                    textView.insertText(textToInsert, replacementRange: selectedRange)
                }
            } else {
                // For final text, update our tracking
                var updatedFinalizedText = finalizedText
                
                if finalizedText.isEmpty {
                    updatedFinalizedText = text
                    onFinalizedTextUpdated(updatedFinalizedText)
                    
                    // Normal insertion
                    textView.insertText(textToInsert, replacementRange: selectedRange)
                } else {
                    // Check if the current text starts with our finalized text
                    if currentText.hasPrefix(finalizedText) {
                        // Append to existing finalized text with a space
                        updatedFinalizedText += " " + text
                        onFinalizedTextUpdated(updatedFinalizedText)
                        
                        // Replace any temporary text after the finalized text
                        if !streamingInsertedText.isEmpty {
                            if let range = currentText.range(of: streamingInsertedText, options: [], range: currentText.index(currentText.startIndex, offsetBy: finalizedText.count - text.count)..<currentText.endIndex) {
                                // Calculate range to replace
                                let startOffset = currentText.distance(from: currentText.startIndex, to: range.lowerBound)
                                let length = streamingInsertedText.count
                                let replaceRange = NSRange(location: startOffset, length: length)
                                
                                // Replace the temporary text
                                textView.replaceCharacters(in: replaceRange, with: text)
                            } else {
                                // If we can't find the temporary text, just append
                                let insertionPoint = NSRange(location: currentText.count, length: 0)
                                textView.insertText((needsLeadingSpace ? " " : "") + text, replacementRange: insertionPoint)
                            }
                        } else {
                            // Just append if no temporary text
                            let insertionPoint = NSRange(location: currentText.count, length: 0)
                            textView.insertText((needsLeadingSpace ? " " : "") + text, replacementRange: insertionPoint)
                        }
                    } else {
                        // The current text doesn't contain our finalized text
                        // Append the new text to our finalized text tracking
                        updatedFinalizedText += " " + text
                        onFinalizedTextUpdated(updatedFinalizedText)
                        
                        // Just insert at the selected range
                        textView.insertText(textToInsert, replacementRange: selectedRange)
                    }
                }
                print("🔄 Updated finalized text: \"\(updatedFinalizedText)\"")
            }
        }
    }
    
    /// Replaces temporary text with final text in a text field
    /// - Parameters:
    ///   - temporaryText: The temporary text to replace
    ///   - finalText: The final text to insert
    ///   - textField: The text field to update
    ///   - finalizedText: The finalized text to preserve
    ///   - wouldCauseRepetition: Function to check if insertion would cause repetition
    ///   - findDivergencePoint: Function to find divergence between texts
    ///   - onFinalizedTextUpdated: Callback to update finalized text
    func replaceTemporaryTextInTextField(
        _ temporaryText: String,
        with finalText: String,
        in textField: NSTextField,
        finalizedText: String,
        wouldCauseRepetition: (String, String) -> Bool,
        findDivergencePoint: (String, String) -> (String, String),
        onFinalizedTextUpdated: @escaping (String) -> Void
    ) {
        let currentText = textField.stringValue
        print("🔄 Current text from text field: \"\(currentText)\"")
        
        // First, check if the final text is significantly different from the temporary text
        let textFormatter = TextFormatter()
        let similarity = textFormatter.calculateTextSimilarity(temporaryText, finalText)
        print("🔄 Text similarity: \(similarity)")
        
        // If the texts are very similar (>90%), we might not need to replace at all
        if similarity > 0.9 {
            print("🔄 Texts are very similar, skipping replacement")
            
            // Update finalized text
            var updatedFinalizedText = finalizedText
            if finalizedText.isEmpty {
                updatedFinalizedText = finalText
            } else {
                // Append to existing finalized text with a space
                updatedFinalizedText += " " + finalText
            }
            onFinalizedTextUpdated(updatedFinalizedText)
            print("🔄 Updated finalized text: \"\(updatedFinalizedText)\"")
            return
        }
        
        if let range = currentText.range(of: temporaryText) {
            // Calculate the range to replace
            var newText = currentText
            
            // Find the point where the temporary and final texts diverge
            let (commonPrefix, replacementText) = findDivergencePoint(temporaryText, finalText)
            print("🔄 Common prefix: \"\(commonPrefix)\"")
            print("🔄 Replacement text: \"\(replacementText)\"")
            
            if commonPrefix.count > 0 && commonPrefix.count < temporaryText.count {
                // If we have a common prefix, only replace the divergent part
                let startIndex = currentText.index(range.lowerBound, offsetBy: commonPrefix.count)
                let replacementRange = startIndex..<range.upperBound
                
                // Replace only the divergent part
                newText.replaceSubrange(replacementRange, with: replacementText)
            } else {
                // Replace the whole temporary text
                newText.replaceSubrange(range, with: finalText)
            }
            
            // Check if the replacement would cause repetition
            if wouldCauseRepetition(currentText, newText) {
                print("⚠️ Replacement would cause repetition, using reset approach")
                
                // Create the text to insert - preserve finalized text if it exists
                var textToInsert = finalText
                if !finalizedText.isEmpty {
                    // Check if the finalized text is already in the current text
                    if currentText.hasPrefix(finalizedText) {
                        // Replace only the part after the finalized text
                        let startIndex = currentText.index(currentText.startIndex, offsetBy: finalizedText.count)
                        let endIndex = currentText.endIndex
                        let textToReplace = String(currentText[startIndex..<endIndex])
                        
                        // Only replace if the text to replace contains our temporary text
                        if textToReplace.contains(temporaryText) {
                            textToInsert = finalizedText + " " + finalText
                        } else {
                            // If we can't find our temporary text after the finalized text,
                            // just use the finalized text to avoid losing it
                            textToInsert = finalizedText
                        }
                    } else {
                        // If the current text doesn't start with our finalized text,
                        // preserve the finalized text and append the new final text
                        textToInsert = finalizedText + " " + finalText
                    }
                }
                
                print("🔄 Setting text field to: \"\(textToInsert)\"")
                textField.stringValue = textToInsert
            } else {
                // Apply the replacement
                print("🔄 Setting text field to: \"\(newText)\"")
                textField.stringValue = newText
            }
            
            // Notify that the text changed
            textField.sendAction(textField.action, to: textField.target)
        } else {
            // If we can't find the temporary text, just append the final text
            print("⚠️ Couldn't find exact temporary text, appending final text")
            let space = currentText.isEmpty ? "" : " "
            textField.stringValue = currentText + space + finalText
            textField.sendAction(textField.action, to: textField.target)
        }
        
        // Update finalized text
        var updatedFinalizedText = finalizedText
        if finalizedText.isEmpty {
            updatedFinalizedText = finalText
        } else {
            // Append to existing finalized text with a space
            updatedFinalizedText += " " + finalText
        }
        onFinalizedTextUpdated(updatedFinalizedText)
        print("🔄 Updated finalized text: \"\(updatedFinalizedText)\"")
    }
    
    /// Replaces temporary text with final text in a text view
    /// - Parameters:
    ///   - temporaryText: The temporary text to replace
    ///   - finalText: The final text to insert
    ///   - textView: The text view to update
    ///   - finalizedText: The finalized text to preserve
    ///   - wouldCauseRepetition: Function to check if insertion would cause repetition
    ///   - findDivergencePoint: Function to find divergence between texts
    ///   - onFinalizedTextUpdated: Callback to update finalized text
    func replaceTemporaryTextInTextView(
        _ temporaryText: String,
        with finalText: String,
        in textView: NSTextView,
        finalizedText: String,
        wouldCauseRepetition: (String, String) -> Bool,
        findDivergencePoint: (String, String) -> (String, String),
        onFinalizedTextUpdated: @escaping (String) -> Void
    ) {
        // For text views, replace the temporary text with the final text
        let currentText = textView.string
        print("🔄 Current text from text view: \"\(currentText)\"")
        
        // First, check if the final text is significantly different from the temporary text
        let textFormatter = TextFormatter()
        let similarity = textFormatter.calculateTextSimilarity(temporaryText, finalText)
        print("🔄 Text similarity: \(similarity)")
        
        // If the texts are very similar (>90%), we might not need to replace at all
        if similarity > 0.9 {
            print("🔄 Texts are very similar, skipping replacement")
            
            // Update finalized text
            var updatedFinalizedText = finalizedText
            if finalizedText.isEmpty {
                updatedFinalizedText = finalText
            } else {
                // Append to existing finalized text with a space
                updatedFinalizedText += " " + finalText
            }
            onFinalizedTextUpdated(updatedFinalizedText)
            print("🔄 Updated finalized text: \"\(updatedFinalizedText)\"")
            return
        }
        
        if let range = currentText.range(of: temporaryText) {
            // Calculate the range to replace
            let startIndex = currentText.distance(from: currentText.startIndex, to: range.lowerBound)
            let length = temporaryText.count
            let replaceRange = NSRange(location: startIndex, length: length)
            
            // Check if the replacement would cause repetition
            let potentialNewText = currentText.replacingOccurrences(of: temporaryText, with: finalText)
            if wouldCauseRepetition(currentText, potentialNewText) {
                print("⚠️ Replacement would cause repetition, using reset approach")
                
                // Create the text to insert - preserve finalized text if it exists
                var textToInsert = finalText
                if !finalizedText.isEmpty {
                    // Check if the finalized text is already in the current text
                    if currentText.hasPrefix(finalizedText) {
                        // Replace only the part after the finalized text
                        let startIndex = currentText.index(currentText.startIndex, offsetBy: finalizedText.count)
                        let endIndex = currentText.endIndex
                        let textToReplace = String(currentText[startIndex..<endIndex])
                        
                        // Only replace if the text to replace contains our temporary text
                        if textToReplace.contains(temporaryText) {
                            textToInsert = finalizedText + " " + finalText
                        } else {
                            // If we can't find our temporary text after the finalized text,
                            // just use the finalized text to avoid losing it
                            textToInsert = finalizedText
                        }
                    } else {
                        // If the current text doesn't start with our finalized text,
                        // preserve the finalized text and append the new final text
                        textToInsert = finalizedText + " " + finalText
                    }
                }
                
                print("🔄 Setting text view to: \"\(textToInsert)\"")
                textView.string = textToInsert
            } else {
                // Apply the replacement
                print("🔄 Replacing characters in text view")
                textView.replaceCharacters(in: replaceRange, with: finalText)
            }
        } else {
            // If we can't find the temporary text, just append the final text
            print("⚠️ Couldn't find exact temporary text, appending final text")
            let space = currentText.isEmpty ? "" : " "
            textView.insertText(space + finalText, replacementRange: NSRange(location: currentText.count, length: 0))
        }
        
        // Update finalized text
        var updatedFinalizedText = finalizedText
        if finalizedText.isEmpty {
            updatedFinalizedText = finalText
        } else {
            // Append to existing finalized text with a space
            updatedFinalizedText += " " + finalText
        }
        onFinalizedTextUpdated(updatedFinalizedText)
        print("🔄 Updated finalized text: \"\(updatedFinalizedText)\"")
    }
    
    /// Simulates a keypress for a specific key code
    /// - Parameters:
    ///   - keyCode: The virtual key code to press
    ///   - modifiers: Optional modifier flags (shift, command, etc.)
    /// - Returns: Whether the key simulation was successful
    func simulateKeypress(keyCode: CGKeyCode, modifiers: CGEventFlags = []) -> Bool {
        // Create event source
        let sourceRef = CGEventSource(stateID: .combinedSessionState)
        
        // Ensure we have a valid event source
        guard let source = sourceRef else {
            print("⚠️ Failed to create CGEventSource for keypress")
            return false
        }
        
        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            print("⚠️ Failed to create key down event for keycode: \(keyCode)")
            return false
        }
        
        // Set modifiers if needed
        if modifiers != [] {
            keyDownEvent.flags = modifiers
        }
        
        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            print("⚠️ Failed to create key up event for keycode: \(keyCode)")
            return false
        }
        
        // Set modifiers for key up too
        if modifiers != [] {
            keyUpEvent.flags = modifiers
        }
        
        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        usleep(500) // Small delay between key down and key up
        keyUpEvent.post(tap: .cghidEventTap)
        
        return true
    }
} 