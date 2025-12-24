import Foundation

/// Responsible for text cleaning, formatting, and overlap detection
class TextFormatter {
    
    // Track segment history for overlap removal
    private var trackedSegments = [String]()
    private var maxTrackedSegments = 5 // Only track the last 5 segments
    
    init() {}
    
    /// Resets the state of tracked segments
    func resetSegmentTracking() {
        trackedSegments = []
        print("🧹 Reset segment tracking state")
    }
    
    /// Detects and removes overlapping text between the new segment and previously stored segments
    /// - Parameter text: The text to check for overlaps
    /// - Returns: The text with any overlapping portions removed
    func removeOverlappingText(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        // Check if we have any tracked segments to compare against
        if trackedSegments.isEmpty {
            // No previous segments to check against, just track this one
            trackedSegments.append(text)
            if trackedSegments.count > maxTrackedSegments {
                trackedSegments.removeFirst()
            }
            return text
        }
        
        var cleanedText = text
        
        // Check against each tracked segment for overlaps
        for previousSegment in trackedSegments {
            // Skip empty segments
            if previousSegment.isEmpty { continue }
            
            // First check for exact duplication
            if previousSegment == cleanedText {
                print("🔍 Detected exact duplicate segment, removing")
                cleanedText = ""
                break
            }
            
            // Check for near duplicate (similarity > 90%)
            let similarity = calculateTextSimilarity(previousSegment, cleanedText)
            if similarity > 0.9 {
                print("🔍 Detected near duplicate segment (similarity: \(similarity)), removing")
                cleanedText = ""
                break
            }
            
            // Check if the new text is a substring of the previous segment
            if previousSegment.contains(cleanedText) {
                print("🔍 New text is completely contained in previous segment, removing")
                cleanedText = ""
                break
            }
            
            // Check if the previous segment is a substring of the new text
            if cleanedText.contains(previousSegment) {
                // Remove the overlapping part (previous segment) from the new text
                cleanedText = cleanedText.replacingOccurrences(of: previousSegment, with: "")
                print("🔍 Previous segment contained in new text, removing overlapping part")
            }
            
            // Check for substantial overlap (where the end of the previous segment overlaps with the start of the new segment)
            // Try different sizes of overlap, starting from the largest possible
            let minOverlapLength = min(min(3, previousSegment.count), cleanedText.count) // At least 3 characters or smaller if texts are shorter
            let maxOverlapLength = min(previousSegment.count, cleanedText.count)
            
            if maxOverlapLength >= minOverlapLength {
                for overlapSize in (minOverlapLength...maxOverlapLength).reversed() {
                    // Get the end part of the previous segment
                    if overlapSize > previousSegment.count { continue }
                    let endIndex = previousSegment.index(previousSegment.endIndex, offsetBy: -overlapSize)
                    let endPart = String(previousSegment[endIndex...])
                    
                    // Get the start part of the new text
                    if overlapSize > cleanedText.count { continue }
                    let startIndex = cleanedText.index(cleanedText.startIndex, offsetBy: overlapSize)
                    let startPart = String(cleanedText[..<startIndex])
                    
                    // Check if they match
                    if endPart == startPart {
                        // Remove the overlapping part from the new text
                        cleanedText = String(cleanedText[startIndex...])
                        print("🔍 Detected \(overlapSize) character overlap, removing")
                        break
                    }
                }
            }
        }
        
        // If we have cleaned text, add it to our tracked segments
        if !cleanedText.isEmpty {
            trackedSegments.append(cleanedText)
            if trackedSegments.count > maxTrackedSegments {
                trackedSegments.removeFirst()
            }
        }
        
        return cleanedText
    }
    
    /// Cleans the input text from unwanted characters and artifacts
    /// - Parameter text: The text to clean
    /// - Returns: The cleaned text
    func cleanText(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        // Remove any special markers or unwanted characters
        var cleanedText = text
        
        // Remove any unwanted characters that aren't valid language characters
        // Keep letters, numbers, punctuation, and whitespace
        let validCharacterSet = CharacterSet.letters.union(.decimalDigits).union(.punctuationCharacters).union(.whitespaces)
        cleanedText = cleanedText.components(separatedBy: validCharacterSet.inverted).joined()
        
        // Remove multiple consecutive whitespaces
        while cleanedText.contains("  ") {
            cleanedText = cleanedText.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Trim leading and trailing whitespace
        cleanedText = cleanedText.trimmingCharacters(in: .whitespaces)
        
        return cleanedText
    }
    
    /// Adds sentence-ending punctuation if it's missing
    /// - Parameter text: The text to punctuate
    /// - Returns: The punctuated text
    func autoPunctuate(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty { return text }
        
        // List of sentence-ending punctuation marks
        let sentenceEnders: Set<Character> = [".", "!", "?", ":", ";"]
        
        // If the last character is not a sentence ender, add a period
        if let lastChar = trimmedText.last, !sentenceEnders.contains(lastChar) {
            return trimmedText + "."
        }
        
        return trimmedText
    }
    
    /// Formats the text before insertion, handling capitalization and word repetition
    /// - Parameters:
    ///   - text: The text to format
    ///   - language: The language of the text
    ///   - lastInsertedText: The last text that was inserted
    ///   - isNewRecordingSession: Whether this is part of a new recording session
    ///   - onLastInsertedTextUpdated: Callback to update the last inserted text tracking
    /// - Returns: The formatted text
    func formatText(
        _ text: String,
        language: String,
        lastInsertedText: String,
        isNewRecordingSession: Bool,
        onLastInsertedTextUpdated: @escaping (String) -> Void
    ) -> String {
        var formattedText = text
        
        // Clean the text from unwanted characters
        formattedText = cleanText(formattedText)
        
        // Only do further processing if we have text after cleaning
        if !formattedText.isEmpty {
            // Handle capitalization - capitalize the first letter if it's the start of a sentence
            if isNewRecordingSession && !formattedText.isEmpty {
                formattedText = formattedText.prefix(1).capitalized + formattedText.dropFirst()
                print("💬 Capitalized first letter (new recording session): \"\(formattedText)\"")
            } else if !isNewRecordingSession && !formattedText.isEmpty {
                // Improve capitalization logic by checking if the previous text ended with punctuation that ends a sentence
                // First, remove any trailing spaces from lastInsertedText to simplify our check
                let trimmedLastText = lastInsertedText.trimmingCharacters(in: .whitespaces)
                
                // Check if the last text ends with sentence-ending punctuation
                let endsWithSentencePunctuation = trimmedLastText.hasSuffix(".") || 
                                                 trimmedLastText.hasSuffix("!") || 
                                                 trimmedLastText.hasSuffix("?")
                
                // Get the first word of the new text for better context assessment
                let firstWord = formattedText.components(separatedBy: " ").first ?? formattedText
                
                // Determine if we should capitalize:
                // 1. If the text is empty (start of recording)
                // 2. If the previous text ended with sentence punctuation
                // 3. NOT if the first word is naturally capitalized like "I" or a proper noun 
                //    (we'll skip this check for now as it's complex to determine proper nouns)
                let shouldCapitalize = trimmedLastText.isEmpty || endsWithSentencePunctuation
                
                // Special case for speech recognition quirks: commonly mid-sentence capitalized words
                let commonMidSentenceWords = ["I", "I'll", "I'd", "I'm", "I've"]
                let isCommonCapitalizedWord = commonMidSentenceWords.contains(firstWord)
                
                if shouldCapitalize && !isCommonCapitalizedWord {
                    formattedText = formattedText.prefix(1).capitalized + formattedText.dropFirst()
                    print("💬 Capitalized first letter: \"\(formattedText)\" (previous text ended with sentence punctuation)")
                } else if isCommonCapitalizedWord {
                    // Preserve capitalization for words like "I"
                    print("💬 Preserved capitalization for common word: \"\(firstWord)\"")
                } else {
                    // Force lowercase for the first letter unless it's at the start of a sentence
                    if !formattedText.isEmpty && formattedText.prefix(1).uppercased() == formattedText.prefix(1) {
                        formattedText = formattedText.prefix(1).lowercased() + formattedText.dropFirst()
                        print("💬 Forced lowercase for first letter: \"\(formattedText)\" (previous: \"\(trimmedLastText)\")")
                    } else {
                        print("💬 Keeping original case: \"\(formattedText)\" (previous: \"\(trimmedLastText)\")")
                    }
                }
            }
            
            // Handle repeated words between last inserted text and new text
            if !isNewRecordingSession && !lastInsertedText.isEmpty {
                // Check for repeated text from the end of lastInsertedText to the beginning of formattedText
                let lastWords = lastInsertedText.components(separatedBy: " ")
                let newWords = formattedText.components(separatedBy: " ")
                
                if !lastWords.isEmpty && !newWords.isEmpty {
                    // Get the last word from the last inserted text
                    let lastWord = lastWords.last!
                    
                    // Check if the first word of the new text is the same as the last word of the last text
                    if !newWords.isEmpty && lastWord.lowercased() == newWords[0].lowercased() {
                        // Remove the first word from the new text to avoid repetition
                        formattedText = newWords.dropFirst().joined(separator: " ")
                    }
                }
            }
            
            // Update last inserted text
            onLastInsertedTextUpdated(formattedText)
        }
        
        return formattedText
    }
    
    /// Finds the point where two strings diverge and returns the common prefix
    /// and the replacement text
    /// - Parameters:
    ///   - oldText: The original text
    ///   - newText: The new text to compare against
    /// - Returns: A tuple with the common prefix and the replacement text
    func findDivergencePoint(_ oldText: String, _ newText: String) -> (commonPrefix: String, replacementText: String) {
        // Find the maximum common prefix
        var commonPrefixLength = 0
        let minLength = min(oldText.count, newText.count)
        
        for i in 0..<minLength {
            let oldIndex = oldText.index(oldText.startIndex, offsetBy: i)
            let newIndex = newText.index(newText.startIndex, offsetBy: i)
            
            if oldText[oldIndex] != newText[newIndex] {
                break
            }
            
            commonPrefixLength += 1
        }
        
        // Extract the common prefix
        let commonPrefix = String(oldText.prefix(commonPrefixLength))
        
        // Extract the replacement text (everything after the common prefix in the new text)
        let replacementText = commonPrefixLength < newText.count ? 
            String(newText.suffix(newText.count - commonPrefixLength)) : ""
        
        return (commonPrefix, replacementText)
    }
    
    /// Calculates the similarity between two strings using Levenshtein distance
    /// - Parameters:
    ///   - a: The first string
    ///   - b: The second string
    /// - Returns: A value between 0 and 1, where 1 is exact match
    func calculateTextSimilarity(_ a: String, _ b: String) -> Double {
        // If either string is empty, return 0 if both are empty, otherwise return 0
        if a.isEmpty && b.isEmpty {
            return 1.0
        } else if a.isEmpty || b.isEmpty {
            return 0.0
        }
        
        // Calculate Levenshtein distance
        let distance = levenshteinDistance(a, b)
        let maxLength = max(a.count, b.count)
        
        // Convert to similarity (1 - normalized distance)
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Calculates Levenshtein distance between two strings
    /// - Parameters:
    ///   - aString: The first string
    ///   - bString: The second string
    /// - Returns: The Levenshtein distance
    private func levenshteinDistance(_ aString: String, _ bString: String) -> Int {
        let a = Array(aString)
        let b = Array(bString)
        
        // Create a matrix with dimensions (a.count+1) x (b.count+1)
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        
        // Initialize the first row and column
        for i in 0...a.count {
            matrix[i][0] = i
        }
        
        for j in 0...b.count {
            matrix[0][j] = j
        }
        
        // Fill the matrix
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    // Characters match, no operation needed
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    // Characters don't match, take the minimum of three operations
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1, // Deletion
                        matrix[i][j-1] + 1, // Insertion
                        matrix[i-1][j-1] + 1 // Substitution
                    )
                }
            }
        }
        
        // The bottom-right cell contains the Levenshtein distance
        return matrix[a.count][b.count]
    }
} 