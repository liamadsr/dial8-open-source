//
//  TranscriptionUtils.swift
//  dial8
//
//  Created by Liam Alizadeh
//

/// TranscriptionUtils provides utility functions for processing transcription data.
///
/// This utility class handles the parsing and extraction of transcription text
/// from JSON responses, specifically designed for the backend's streaming format.
///
/// Features:
/// - JSON response parsing
/// - Transcription text extraction
/// - Whitespace normalization
/// - Concatenation of multiple transcript segments
///
/// Implementation Details:
/// - Handles segmented JSON responses
/// - Validates JSON structure
/// - Extracts 'transcript' field from JSON
/// - Joins multiple segments with proper spacing
///
/// Error Handling:
/// - Gracefully handles malformed JSON
/// - Skips invalid segments
/// - Maintains partial results on partial failures
///
/// Usage:
/// ```swift
/// let jsonResponse = "{\"transcript\": \"Hello\"}{\"transcript\": \"World\"}"
/// let text = TranscriptionUtils.extractTranscription(from: jsonResponse)
/// // Result: "Hello World"
/// ```

import Foundation

class TranscriptionUtils {
     static func extractTranscription(from jsonString: String) -> String {
         // Adjust this parser according to your backend's response format
         let components = jsonString.components(separatedBy: "}{")
         let transcripts = components.compactMap { component -> String? in
             // Ensure each component is a valid JSON object
             let jsonComponent = "{\(component.trimmingCharacters(in: CharacterSet(charactersIn: "{}")))}"
             guard let data = jsonComponent.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let transcript = json["transcript"] as? String else {
                 return nil
             }
             return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
         }
         return transcripts.joined(separator: " ")
     }
}