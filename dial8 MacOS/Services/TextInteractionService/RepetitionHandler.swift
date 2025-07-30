import Foundation
import AppKit

/// Responsible for detecting and fixing text repetition issues
class RepetitionHandler {
    
    private let directTextInsertion: DirectTextInsertion
    private let textFormatter: TextFormatter
    
    init(directTextInsertion: DirectTextInsertion, textFormatter: TextFormatter) {
        self.directTextInsertion = directTextInsertion
        self.textFormatter = textFormatter
    }
    
    /// Detects and fixes problematic repetition patterns in the active text field or view
    /// - Parameters:
    ///   - activeTextField: The active text field (if any)
    ///   - activeTextView: The active text view (if any)
    ///   - finalizedText: The finalized text to preserve
    /// - Returns: Whether a fix was applied
    func detectAndFixProblematicPattern(
        activeTextField: NSTextField?,
        activeTextView: NSTextView?,
        finalizedText: String
    ) -> Bool {
        // Get the current text from the active text field or view
        let currentText: String
        if let textField = activeTextField {
            currentText = textField.stringValue
        } else if let textView = activeTextView {
            currentText = textView.string
        } else {
            return false
        }
        
        // Check if the current text contains problematic repetition patterns
        if hasRepeatedPhrases(in: currentText) {
            print("⚠️ Detected problematic repetition pattern")
            
            // Try to fix the repetition
            let cleanedText = handleProblematicRepetitionPattern(in: currentText)
            
            if cleanedText != currentText {
                print("🧹 Applying fix for repetition pattern")
                return performCompleteTextCleanup(
                    cleanedText: cleanedText,
                    activeTextField: activeTextField,
                    activeTextView: activeTextView,
                    finalizedText: finalizedText
                )
            }
        }
        
        return false
    }
    
    /// Performs a complete cleanup of the text field or view when severe repetition is detected
    /// - Parameters:
    ///   - cleanedText: The cleaned text to insert
    ///   - activeTextField: The active text field (if any)
    ///   - activeTextView: The active text view (if any)
    ///   - finalizedText: The finalized text to preserve
    /// - Returns: Whether the cleanup was successful
    func performCompleteTextCleanup(
        cleanedText: String,
        activeTextField: NSTextField?,
        activeTextView: NSTextView?,
        finalizedText: String
    ) -> Bool {
        // Update our tracking of finalized text
        let onFinalizedTextUpdated: (String) -> Void = { _ in }
        
        // Apply the cleanup
        return directTextInsertion.resetTextFieldAndInsertFinalText(
            cleanedText,
            activeTextField: activeTextField,
            activeTextView: activeTextView,
            finalizedText: finalizedText,
            onFinalizedTextUpdated: onFinalizedTextUpdated
        )
    }
    
    /// Checks if inserting new text would cause repetition based on the current text
    /// - Parameters:
    ///   - currentText: The current text content
    ///   - newText: The potential new text content after update
    /// - Returns: Whether the new text would cause repetition
    func wouldCauseRepetition(currentText: String, newText: String) -> Bool {
        // Skip check for empty or short texts
        if currentText.isEmpty || newText.isEmpty || currentText.count < 10 {
            return false
        }
        
        // Check if the current text is being repeated in the new text
        if newText.contains(currentText) && newText != currentText {
            // Check if it's a simple append operation
            if newText.hasPrefix(currentText) && newText.count > currentText.count {
                let appendedText = String(newText.dropFirst(currentText.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip if the appended text is just a short word or phrase
                if appendedText.split(separator: " ").count <= 2 {
                    return false
                }
                
                // Check if the appended text is repeated from earlier in the current text
                let words = currentText.split(separator: " ").map(String.init)
                let appendedWords = appendedText.split(separator: " ").map(String.init)
                
                // Need at least 3 words to check for meaningful repetition
                if appendedWords.count >= 3 {
                    // Create potential phrases to check
                    for i in 0...(words.count - appendedWords.count) {
                        let segment = words[i..<(i + appendedWords.count)].joined(separator: " ")
                        let similarity = textFormatter.calculateTextSimilarity(segment, appendedText)
                        
                        // If similarity is high, it's a repetition
                        if similarity > 0.8 {
                            print("⚠️ Detected potential repetition: \"\(segment)\" vs \"\(appendedText)\"")
                            return true
                        }
                    }
                }
            }
        }
        
        // Check for repeated sections within the new text itself
        if hasRepeatedPhrases(in: newText) {
            print("⚠️ Detected repeated phrases in new text")
            return true
        }
        
        return false
    }
    
    /// Checks if the provided text contains repeated phrases
    /// - Parameter text: The text to check for repetition
    /// - Returns: Whether the text contains repeated phrases
    func hasRepeatedPhrases(in text: String) -> Bool {
        // Text needs to be long enough to check for repetition
        if text.count < 15 {
            return false
        }
        
        let words = text.split(separator: " ").map(String.init)
        
        // Need at least 6 words to check for phrase repetition
        if words.count < 6 {
            return false
        }
        
        // Check for complete duplication of the text
        if let middleIndex = text.index(text.startIndex, offsetBy: text.count / 2, limitedBy: text.endIndex) {
            let firstHalf = String(text[..<middleIndex])
            let secondHalf = String(text[middleIndex...])
            
            let similarity = textFormatter.calculateTextSimilarity(firstHalf, secondHalf)
            if similarity > 0.8 {
                print("⚠️ Detected similar halves in text (similarity: \(similarity))")
                return true
            }
        }
        
        // Check for identical adjacent sentences
        let sentences = text.components(separatedBy: ".").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if sentences.count >= 2 {
            for i in 0..<sentences.count-1 {
                if sentences[i].count > 10 { // Only consider substantial sentences
                    let similarity = textFormatter.calculateTextSimilarity(sentences[i], sentences[i+1])
                    if similarity > 0.8 {
                        print("⚠️ Detected similar adjacent sentences (similarity: \(similarity))")
                        return true
                    }
                }
            }
        }
        
        // Check for repeated phrases
        if words.count >= 8 {
            for phraseLength in (3...min(6, words.count / 2)).reversed() {
                for i in 0...(words.count - phraseLength * 2) {
                    let phrase1 = words[i..<(i + phraseLength)].joined(separator: " ").lowercased()
                    
                    // Look for the same phrase later in the text
                    for j in (i + phraseLength)...(words.count - phraseLength) {
                        let phrase2 = words[j..<(j + phraseLength)].joined(separator: " ").lowercased()
                        
                        // Calculate similarity between phrases
                        let similarity = textFormatter.calculateTextSimilarity(phrase1, phrase2)
                        if similarity > 0.9 {
                            print("⚠️ Detected repeated phrase: \"\(phrase1)\" and \"\(phrase2)\" (similarity: \(similarity))")
                            return true
                        }
                    }
                }
            }
        }
        
        // Check for stuttering words (same word repeated 3+ times)
        for i in 0..<words.count-2 {
            if words[i].count > 2 { // Only consider substantial words
                if words[i].lowercased() == words[i+1].lowercased() && 
                   words[i].lowercased() == words[i+2].lowercased() {
                    print("⚠️ Detected word stuttering: \"\(words[i])\" repeated 3+ times")
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Handles problematic repetition patterns by attempting to extract the first meaningful sentence
    /// or cleaning up the text
    /// - Parameter text: The text with repetition issues
    /// - Returns: The cleaned-up text
    func handleProblematicRepetitionPattern(in text: String) -> String {
        // Try to extract just the first meaningful sentence
        let sentences = text.components(separatedBy: ".").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        if let firstSentence = sentences.first, !firstSentence.isEmpty, firstSentence.count > 10 {
            print("🧹 Extracting first meaningful sentence: \"\(firstSentence)\"")
            return firstSentence + "."
        }
        
        // If we can't extract a good sentence, try a more aggressive cleanup
        return cleanRepeatedText(text)
    }
    
    /// Cleans text with repetitions using a more aggressive approach
    /// - Parameter text: The text to clean
    /// - Returns: The cleaned text
    func cleanRepeatedText(_ text: String) -> String {
        // Split into sentences
        var sentences = text.components(separatedBy: ".").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        
        // If we don't have any usable sentences, return the original text
        if sentences.isEmpty {
            return text
        }
        
        // Remove duplicate or highly similar sentences
        var uniqueSentences: [String] = []
        for sentence in sentences {
            var isDuplicate = false
            
            for existingSentence in uniqueSentences {
                let similarity = textFormatter.calculateTextSimilarity(existingSentence, sentence)
                if similarity > 0.7 {
                    isDuplicate = true
                    break
                }
            }
            
            if !isDuplicate {
                // Clean any internal repetition within the sentence
                let cleanedSentence = removeRepeatedPhrasesInSentence(sentence)
                uniqueSentences.append(cleanedSentence)
            }
        }
        
        // If we've removed all sentences, keep at least the first one
        if uniqueSentences.isEmpty && !sentences.isEmpty {
            uniqueSentences.append(sentences[0])
        }
        
        // Combine the unique sentences back together
        let result = uniqueSentences.joined(separator: ". ")
        return result.hasSuffix(".") ? result : result + "."
    }
    
    /// Removes repeated phrases within a single sentence
    /// - Parameter sentence: The sentence to clean
    /// - Returns: The cleaned sentence
    func removeRepeatedPhrasesInSentence(_ sentence: String) -> String {
        let words = sentence.split(separator: " ").map(String.init)
        
        // If the sentence is too short, just return it as is
        if words.count < 6 {
            return sentence
        }
        
        var cleanedWords: [String] = []
        var i = 0
        
        while i < words.count {
            let word = words[i]
            cleanedWords.append(word)
            
            // Skip ahead past any immediate repetitions of this word
            var j = i + 1
            while j < words.count && textFormatter.calculateTextSimilarity(words[i], words[j]) > 0.9 {
                j += 1
            }
            
            if j > i + 1 {
                print("🧹 Skipping repeated word: \"\(word)\"")
                i = j // Jump ahead
            } else {
                i += 1 // Normal advance
            }
        }
        
        return cleanedWords.joined(separator: " ")
    }
} 