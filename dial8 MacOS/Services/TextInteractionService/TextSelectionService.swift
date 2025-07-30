import Cocoa
import Foundation

class TextSelectionService {
    static let shared = TextSelectionService()
    
    // Use a queue for text retrieval operations
    private let operationQueue = DispatchQueue(label: "com.dial8.textSelectionService", qos: .userInitiated)
    
    // Keep track of which apps have failed accessibility checks
    private var accessibilityRestrictedApps = Set<String>()
    
    // Common code editor bundle identifier patterns - always use clipboard for these
    private let commonCodeEditorPatterns = [
        "code", "editor", "studio", "vscode", "xcode", "sublime", "atom", "jetbrains", 
        "intellij", "pycharm", "webstorm", "cursor", "nova", "vim", "emacs", "textmate"
    ]
    
    // Apps that we know from experience need clipboard fallback
    private let knownClipboardFallbackApps = [
        "com.microsoft.VSCode",
        "com.visualstudio.code",
        "com.apple.dt.Xcode",
        "com.sublimetext",
        "io.cursor",
        "com.panic.Nova",
        "com.barebones.bbedit",
        "org.vim",
        "com.jetbrains"
    ]
    
    private init() {
        // Check accessibility permissions on init
        checkAccessibilityPermission()
    }
    
    // Method to check if the app has accessibility permission
    func checkAccessibilityPermission() {
        let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptionPrompt: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        print("📝 TextSelectionService: App has accessibility permission: \(trusted)")
    }
    
    func getSelectedText() -> String? {
        print("📝 TextSelectionService: Getting selected text")
        
        // Get current app's bundle ID
        let focusedAppBundleID = getFocusedApplicationBundleID() ?? "unknown"
        let appName = getFocusedApplicationName()?.lowercased() ?? ""
        
        print("📝 TextSelectionService: Current app is \(appName) (\(focusedAppBundleID))")
        
        // Force reset state to ensure we're always getting fresh selection
        let pasteboard = NSPasteboard.general
        let oldContent = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        if let oldContent = oldContent {
            pasteboard.setString(oldContent, forType: .string)
        }
        
        // Reset any app-specific cache if needed for specific applications
        if focusedAppBundleID.contains("code") || 
           focusedAppBundleID.contains("editor") ||
           appName.contains("code") || 
           appName.contains("editor") {
            print("📝 TextSelectionService: Code editor detected, applying special handling")
            // For code editors, we'll prioritize the clipboard approach
            let clipboardResult = tryGetSelectedTextViaClipboard()
            if let result = clipboardResult {
                return result
            }
            
            // If clipboard failed, fall back to accessibility
            let (accessibilityResult, _) = tryGetSelectedTextViaAccessibility()
            return accessibilityResult
        }
        
        // Detect if current app is likely a code editor
        let isCodeEditor = isLikelyCodeEditor(bundleID: focusedAppBundleID, appName: appName)
        
        // For code editors, always try both methods (accessibility and clipboard)
        // Code editors often have selected text that's not accessible via accessibility APIs
        if isCodeEditor {
            print("📝 TextSelectionService: Detected likely code editor: \(focusedAppBundleID), trying both methods")
            
            // First try accessibility - it might work
            let (accessibilityResult, _) = tryGetSelectedTextViaAccessibility()
            
            // If we got text via accessibility, return it
            if let text = accessibilityResult, !text.isEmpty {
                print("📝 TextSelectionService: Successfully got text from code editor via accessibility")
                return text
            }
            
            // Otherwise, always try clipboard for code editors, regardless of the element info
            print("📝 TextSelectionService: Code editor, using clipboard fallback")
            let clipboardResult = tryGetSelectedTextViaClipboard()
            
            if clipboardResult != nil {
                print("📝 TextSelectionService: Successfully got text from code editor via clipboard")
            } else {
                print("📝 TextSelectionService: No text found in code editor via either method")
            }
            
            return clipboardResult
        }
        
        // Check if this app is known to restrict accessibility
        if accessibilityRestrictedApps.contains(focusedAppBundleID) {
            print("📝 TextSelectionService: App known to restrict accessibility, using clipboard directly")
            return tryGetSelectedTextViaClipboard()
        }
        
        // Try accessibility API first - it's fast and non-intrusive
        let (accessibilityResult, elementInfo) = tryGetSelectedTextViaAccessibility()
        
        // If we got definitive text via accessibility, return it
        if let text = accessibilityResult, !text.isEmpty {
            print("📝 TextSelectionService: Successfully got text via accessibility")
            return text
        }
        
        // Check if accessibility appears to be restricted
        if elementInfo.accessibilityRestricted {
            print("📝 TextSelectionService: Accessibility appears restricted, adding app to restricted list")
            accessibilityRestrictedApps.insert(focusedAppBundleID)
            return tryGetSelectedTextViaClipboard()
        }
        
        // Determine if clipboard attempt would be appropriate based on element properties
        let shouldTryClipboard = elementInfo.shouldAttemptCopy
        
        if !shouldTryClipboard {
            print("📝 TextSelectionService: Element not suitable for copy, skipping clipboard: \(elementInfo.reason)")
            return nil
        }
        
        // Try clipboard as fallback for suitable elements
        print("📝 TextSelectionService: Element suitable for copy: \(elementInfo.reason), trying clipboard")
        let clipboardResult = tryGetSelectedTextViaClipboard()
        
        if clipboardResult != nil {
            print("📝 TextSelectionService: Successfully got text via clipboard")
        } else {
            print("📝 TextSelectionService: No text found via clipboard either")
        }
        
        return clipboardResult
    }
    
    // Checks if the current app is likely a code editor based on its bundle ID or name
    private func isLikelyCodeEditor(bundleID: String, appName: String) -> Bool {
        // First check against known code editor bundle IDs
        for pattern in knownClipboardFallbackApps {
            if bundleID.hasPrefix(pattern) {
                return true
            }
        }
        
        // Check if bundle ID contains any code editor-related keywords
        for pattern in commonCodeEditorPatterns {
            if bundleID.lowercased().contains(pattern) {
                return true
            }
        }
        
        // Check if app name contains any code editor-related keywords
        for pattern in commonCodeEditorPatterns {
            if appName.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    // Get bundle ID for the focused application
    private func getFocusedApplicationBundleID() -> String? {
        // Get the frontmost application using NSWorkspace instead of accessibility
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return frontmostApp.bundleIdentifier
        }
        return nil
    }
    
    // Get the name of the focused application
    private func getFocusedApplicationName() -> String? {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            return frontmostApp.localizedName
        }
        return nil
    }
    
    // Information about the element we're interacting with
    struct ElementInfo {
        let role: String?
        let isTextField: Bool
        let isTextualElement: Bool
        let hasTextChildren: Bool
        let hasInteractableArea: Bool
        let shouldAttemptCopy: Bool
        let accessibilityRestricted: Bool
        let reason: String
    }
    
    // Returns a tuple of (selected text, element info)
    private func tryGetSelectedTextViaAccessibility() -> (String?, ElementInfo) {
        // This method is already optimized and fast
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedAppRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString, 
            &focusedAppRef
        )
        
        // Check if accessibility might be restricted
        let possibleAccessibilityRestriction = (error == .cannotComplete || error == .notImplemented || error == .apiDisabled)
        
        if possibleAccessibilityRestriction {
            print("📝 TextSelectionService: Accessibility API error: \(error), possible restriction")
            return (nil, ElementInfo(
                role: nil,
                isTextField: false,
                isTextualElement: false,
                hasTextChildren: false,
                hasInteractableArea: false,
                shouldAttemptCopy: true, // Try clipboard anyway
                accessibilityRestricted: true,
                reason: "Accessibility API error: \(error)"
            ))
        }
        
        guard error == .success, let focusedAppRef = focusedAppRef else {
            print("📝 TextSelectionService: No focused app found")
            return (nil, ElementInfo(
                role: nil,
                isTextField: false,
                isTextualElement: false,
                hasTextChildren: false,
                hasInteractableArea: false,
                shouldAttemptCopy: false,
                accessibilityRestricted: false,
                reason: "No focused app"
            ))
        }
        
        // Convert to AXUIElement
        let focusedApp = focusedAppRef as! AXUIElement
        
        var focusedElementRef: CFTypeRef?
        let focusError = AXUIElementCopyAttributeValue(
            focusedApp, 
            kAXFocusedUIElementAttribute as CFString, 
            &focusedElementRef
        )
        
        // Another check for accessibility restrictions
        if focusError == .cannotComplete || focusError == .notImplemented || focusError == .apiDisabled {
            print("📝 TextSelectionService: Focused element error: \(focusError), possible restriction")
            return (nil, ElementInfo(
                role: nil,
                isTextField: false,
                isTextualElement: false,
                hasTextChildren: false,
                hasInteractableArea: false,
                shouldAttemptCopy: true, // Try clipboard anyway
                accessibilityRestricted: true,
                reason: "Accessibility restricted: \(focusError)"
            ))
        }
        
        guard focusError == .success, let focusedElementRef = focusedElementRef else {
            print("📝 TextSelectionService: No focused element found")
            return (nil, ElementInfo(
                role: nil,
                isTextField: false,
                isTextualElement: false,
                hasTextChildren: false,
                hasInteractableArea: false,
                shouldAttemptCopy: false,
                accessibilityRestricted: false,
                reason: "No focused element"
            ))
        }
        
        // Convert to AXUIElement
        let focusedElement = focusedElementRef as! AXUIElement
        
        // First check if there's selected text
        var selectedTextRef: CFTypeRef?
        let textError = AXUIElementCopyAttributeValue(
            focusedElement, 
            kAXSelectedTextAttribute as CFString, 
            &selectedTextRef
        )
        
        // Check for accessibility restrictions in text retrieval
        if textError == .cannotComplete || textError == .notImplemented || textError == .apiDisabled {
            print("📝 TextSelectionService: Selected text error: \(textError), possible restriction")
            return (nil, ElementInfo(
                role: nil,
                isTextField: false,
                isTextualElement: false,
                hasTextChildren: false,
                hasInteractableArea: false,
                shouldAttemptCopy: true, // Try clipboard anyway
                accessibilityRestricted: true,
                reason: "Accessibility restricted: \(textError)"
            ))
        }
        
        if textError == .success, let text = selectedTextRef as? String {
            print("📝 TextSelectionService: Found selected text via accessibility: \"\(text)\"")
            if !text.isEmpty {
                return (text, ElementInfo(
                    role: getRoleOfElement(focusedElement),
                    isTextField: true,
                    isTextualElement: true,
                    hasTextChildren: false,
                    hasInteractableArea: true,
                    shouldAttemptCopy: true,
                    accessibilityRestricted: false,
                    reason: "Has selected text"
                ))
            } else {
                print("📝 TextSelectionService: Selected text was empty")
            }
        } else {
            print("📝 TextSelectionService: Could not get selected text, error: \(textError)")
        }
        
        // If we couldn't get selected text, check other properties of the element
        let role = getRoleOfElement(focusedElement)
        let isTextField = isTextFieldElement(role)
        let isTextualElement = isTextualElementType(role)
        let hasValue = elementHasValue(focusedElement)
        let hasTextChildren = hasTextualChildren(focusedElement)
        let hasInteractableArea = hasSelectionOrInteractiveArea(focusedElement)
        
        // Log what we found
        if let role = role {
            print("📝 TextSelectionService: Element role: \(role)")
            print("📝 TextSelectionService: isTextField: \(isTextField), isTextualElement: \(isTextualElement), hasValue: \(hasValue), hasTextChildren: \(hasTextChildren)")
        }
        
        // Decision logic for whether we should attempt clipboard copy
        let shouldAttemptCopy: Bool
        let reason: String
        
        if isTextField {
            shouldAttemptCopy = true
            reason = "Is text field"
        } else if isTextualElement {
            shouldAttemptCopy = true
            reason = "Is textual element"
        } else if hasValue {
            shouldAttemptCopy = true
            reason = "Has value attribute"
        } else if hasTextChildren {
            shouldAttemptCopy = true
            reason = "Has textual children"
        } else if hasInteractableArea {
            shouldAttemptCopy = true
            reason = "Has interactable area"
        } else {
            shouldAttemptCopy = false
            reason = "No text-related properties found"
        }
        
        return (nil, ElementInfo(
            role: role,
            isTextField: isTextField,
            isTextualElement: isTextualElement,
            hasTextChildren: hasTextChildren,
            hasInteractableArea: hasInteractableArea,
            shouldAttemptCopy: shouldAttemptCopy,
            accessibilityRestricted: false,
            reason: reason
        ))
    }
    
    // Helper function to get the role of an element
    private func getRoleOfElement(_ element: AXUIElement) -> String? {
        var roleRef: CFTypeRef?
        let roleError = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleRef
        )
        
        if roleError == .success, let role = roleRef as? String {
            return role
        }
        return nil
    }
    
    // Helper function to check if an element has a text-related role
    private func isTextFieldElement(_ role: String?) -> Bool {
        guard let role = role else { return false }
        
        return role == kAXTextFieldRole as String || 
               role == kAXTextAreaRole as String ||
               role == "AXTextField" ||
               role == "AXTextArea"
    }
    
    // Helper function to check if an element is textual in nature
    private func isTextualElementType(_ role: String?) -> Bool {
        guard let role = role else { return false }
        
        return isTextFieldElement(role) ||
               role == "AXStaticText" ||
               role == kAXStaticTextRole as String ||
               role == "AXWebArea" ||
               role.contains("Text") ||
               role.contains("text") ||
               role.contains("Editor") ||
               role.contains("Document")
    }
    
    // Helper function to check if an element has a value attribute
    private func elementHasValue(_ element: AXUIElement) -> Bool {
        var valueRef: CFTypeRef?
        let valueError = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueRef
        )
        
        return valueError == .success && valueRef != nil
    }
    
    // Helper function to check if an element has text children
    private func hasTextualChildren(_ element: AXUIElement) -> Bool {
        var childrenRef: CFTypeRef?
        let childrenError = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &childrenRef
        )
        
        if childrenError == .success, let children = childrenRef as? [AXUIElement], !children.isEmpty {
            // Check if any of the first few children are text elements
            for child in children.prefix(5) {
                if let role = getRoleOfElement(child), isTextualElementType(role) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // Helper function to check if an element has selection or interactive properties
    private func hasSelectionOrInteractiveArea(_ element: AXUIElement) -> Bool {
        // Check for common attributes that suggest text selection might be possible
        let selectionAttributes = [
            kAXSelectedTextAttribute,
            kAXSelectedTextRangeAttribute,
            "AXSelectedTextMarkerRange"
        ]
        
        for attribute in selectionAttributes {
            var attrRef: CFTypeRef?
            let attrError = AXUIElementCopyAttributeValue(
                element,
                attribute as CFString,
                &attrRef
            )
            
            if attrError == .success && attrRef != nil {
                return true
            }
        }
        
        return false
    }
    
    private func tryGetSelectedTextViaClipboard() -> String? {
        print("📝 TextSelectionService: Attempting to get selected text via clipboard")
        
        // Store the current clipboard content
        let pasteboard = NSPasteboard.general
        let oldClipboardContent = pasteboard.string(forType: .string)
        
        // Clear the pasteboard first to ensure we're not getting stale data
        pasteboard.clearContents()
        
        // Short delay to ensure clipboard is cleared
        usleep(10000) // 10ms
        
        // Function to restore clipboard content
        let restoreClipboard = {
            pasteboard.clearContents()
            if let oldContent = oldClipboardContent {
                pasteboard.setString(oldContent, forType: .string)
            }
        }
        
        // Add a small delay to ensure the OS has time to update the selection
        // This helps prevent a race condition when quickly switching between apps
        usleep(20000) // 20ms delay before sending CMD+C
        
        // Using a more direct approach to avoid delays
        // Send CMD+C keystroke with minimal delays
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Create CMD+C keystrokes
        let keyC = CGKeyCode(8) // Virtual key code for 'c'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        
        // Set command flag
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        // Post events
        keyDown?.post(tap: .cghidEventTap)
        // Only tiny delay between down and up
        usleep(5000) // 5ms
        keyUp?.post(tap: .cghidEventTap)
        
        // Increase the wait time for clipboard to ensure it captures the new content
        usleep(100000) // 100ms (increased from 50ms)
        
        // Check clipboard
        let newClipboardContent = pasteboard.string(forType: .string)
        
        print("📝 TextSelectionService: Old clipboard: \(oldClipboardContent?.prefix(20) ?? "(nil)"), New clipboard: \(newClipboardContent?.prefix(20) ?? "(nil)")")
        
        // Return the new content if it exists and differs from the old one
        if let newContent = newClipboardContent, 
           (oldClipboardContent == nil || newContent != oldClipboardContent) {
            print("📝 TextSelectionService: Found new clipboard content")
            // Restore original clipboard content asynchronously
            // Increase the delay to give more time before restoring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                restoreClipboard()
            }
            return newContent
        }
        
        print("📝 TextSelectionService: No new clipboard content found")
        // Restore original clipboard content
        restoreClipboard()
        return nil
    }
} 
