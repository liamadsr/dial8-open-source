import Foundation
import AppKit

/// Responsible for inserting text via clipboard operations
class ClipboardTextInsertion {
    
    // Original clipboard content to restore after operations
    private var originalClipboardContent: NSString?
    private var hasStoredClipboard = false
    
    init() {}
    
    /// Saves the current clipboard content for later restoration
    func saveClipboardContent() {
        if let currentContent = NSPasteboard.general.pasteboardItems?.first?.data(forType: .string) {
            originalClipboardContent = NSString(data: currentContent, encoding: String.Encoding.utf8.rawValue)
            hasStoredClipboard = true
            print("📋 Saved original clipboard content")
        } else {
            originalClipboardContent = nil
            hasStoredClipboard = false
            print("📋 No clipboard content to save")
        }
    }
    
    /// Restores the original clipboard content
    func restoreClipboardContent() {
        if hasStoredClipboard, let originalContent = originalClipboardContent {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(originalContent as String, forType: .string)
            print("📋 Restored original clipboard content")
        } else {
            print("📋 No clipboard content to restore")
        }
        
        // Reset our tracking state
        hasStoredClipboard = false
        originalClipboardContent = nil
    }
    
    /// Inserts text by copying to clipboard and pasting
    /// - Parameters:
    ///   - text: The text to insert
    ///   - preserveClipboard: Whether to preserve the clipboard content
    /// - Returns: Whether the insertion was successful
    func insertText(_ text: String, preserveClipboard: Bool = true) -> Bool {
        print("📋 Inserting text via clipboard: \"\(text)\"")
        
        // Save original clipboard content if needed
        if preserveClipboard {
            saveClipboardContent()
        }
        
        // Copy the text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate CMD+V to paste
        let result = simulatePaste()
        
        // Restore original clipboard if needed
        if preserveClipboard {
            // Small delay to ensure pasting completes before we restore the clipboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.restoreClipboardContent()
            }
        }
        
        return result
    }
    
    /// Simulates pressing CMD+V to paste
    /// - Returns: Whether the paste action was successful
    private func simulatePaste() -> Bool {
        // Create a CMD+V key event
        let cmdKey = CGEventFlags.maskCommand
        
        guard let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
            print("⚠️ Failed to create key down event")
            return false
        }
        
        guard let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            print("⚠️ Failed to create key up event")
            return false
        }
        
        // Set the command flag
        cmdDown.flags = cmdKey
        cmdUp.flags = cmdKey
        
        // Post the key events to simulate CMD+V
        cmdDown.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp.post(tap: .cgAnnotatedSessionEventTap)
        
        print("📋 Simulated CMD+V paste action")
        return true
    }
    
    /// Updates text by doing a select all, then paste operation
    /// - Parameters:
    ///   - text: The text to insert
    ///   - preserveClipboard: Whether to preserve the clipboard content
    /// - Returns: Whether the update was successful
    func updateEntireText(_ text: String, preserveClipboard: Bool = true) -> Bool {
        print("📋 Updating entire text via clipboard: \"\(text)\"")
        
        // Save original clipboard content if needed
        if preserveClipboard {
            saveClipboardContent()
        }
        
        // Copy the text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate CMD+A to select all
        let selectResult = simulateSelectAll()
        if !selectResult {
            print("⚠️ Failed to select all text")
            if preserveClipboard {
                restoreClipboardContent()
            }
            return false
        }
        
        // Simulate CMD+V to paste
        let pasteResult = simulatePaste()
        
        // Restore original clipboard if needed
        if preserveClipboard {
            // Small delay to ensure pasting completes before we restore the clipboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.restoreClipboardContent()
            }
        }
        
        return pasteResult
    }
    
    /// Simulates pressing CMD+A to select all text
    /// - Returns: Whether the select all action was successful
    private func simulateSelectAll() -> Bool {
        // Create a CMD+A key event
        let cmdKey = CGEventFlags.maskCommand
        
        guard let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true) else {
            print("⚠️ Failed to create key down event")
            return false
        }
        
        guard let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: false) else {
            print("⚠️ Failed to create key up event")
            return false
        }
        
        // Set the command flag
        cmdDown.flags = cmdKey
        cmdUp.flags = cmdKey
        
        // Post the key events to simulate CMD+A
        cmdDown.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp.post(tap: .cgAnnotatedSessionEventTap)
        
        print("📋 Simulated CMD+A select all action")
        
        // Small delay to ensure selection completes before we continue
        Thread.sleep(forTimeInterval: 0.1)
        
        return true
    }
    
    /// Updates text while preserving finalized text using clipboard
    /// - Parameters:
    ///   - text: The new text to insert
    ///   - finalizedText: The finalized text to preserve
    ///   - preserveClipboard: Whether to preserve the clipboard content
    /// - Returns: Whether the update was successful
    func updateTextPreservingFinalized(_ text: String, finalizedText: String, preserveClipboard: Bool = true) -> Bool {
        // If no finalized text, just do a normal update
        if finalizedText.isEmpty {
            return insertText(text, preserveClipboard: preserveClipboard)
        }
        
        // Calculate the text to insert - preserve finalized text
        let textToInsert: String
        if text.hasPrefix(finalizedText) {
            // The new text already contains the finalized text
            textToInsert = text
        } else {
            // Need to prepend finalized text
            textToInsert = finalizedText + " " + text
        }
        
        return updateEntireText(textToInsert, preserveClipboard: preserveClipboard)
    }
} 