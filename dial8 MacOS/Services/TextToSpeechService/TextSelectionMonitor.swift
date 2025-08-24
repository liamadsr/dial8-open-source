import Foundation
import Cocoa
import Combine

class TextSelectionMonitor: ObservableObject {
    static let shared = TextSelectionMonitor()
    
    // MARK: - Published Properties
    @Published private(set) var hasSelectedText = false
    @Published private(set) var selectedText: String?
    @Published private(set) var isMonitoring = false
    
    // MARK: - Private Properties
    private var eventMonitor: Any?
    private var lastSelectedText: String?
    private var selectionCheckTimer: Timer?
    private let selectionCheckDelay: TimeInterval = 0.05 // Quick response for snappy feel
    private var hudController: TTSHUDController?
    private var isCheckingSelection = false
    private var isSwitchingText = false // Flag to prevent auto-dismiss when switching text
    private var lastHUDActionTime: Date = Date.distantPast // Track last HUD show/hide to prevent rapid changes
    private var mouseDownLocation: NSPoint? // Track where mouse was pressed down
    private var isDragging = false // Track if user is dragging to select text
    private var lastClickTime: Date = Date.distantPast // Track time of last click for double-click detection
    private var clickCount = 0 // Track click count for double/triple click
    
    // MARK: - Initialization
    private init() {
        print("📋 TextSelectionMonitor: Initialized")
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        print("📋 TextSelectionMonitor: Starting monitoring")
        isMonitoring = true
        
        // Monitor mouse events to detect when user might be selecting text
        // Monitor mouse down, dragged, and up to detect selection gestures
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("📋 TextSelectionMonitor: Stopping monitoring")
        isMonitoring = false
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        selectionCheckTimer?.invalidate()
        selectionCheckTimer = nil
        
        // Clear state
        hasSelectedText = false
        selectedText = nil
        lastSelectedText = nil
        
        // Hide HUD if it's showing
        hideHUD()
    }
    
    func forceHideHUD() {
        print("📋 TextSelectionMonitor: Force hiding TTS HUD")
        
        // Clear flags that might prevent hiding
        isSwitchingText = false
        
        // Force hide the HUD
        hideHUD(force: true)
        
        // Clear state
        hasSelectedText = false
        selectedText = nil
        lastSelectedText = nil
    }
    
    // MARK: - Private Methods
    
    private func handleMouseEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            // Record where the mouse was pressed down
            mouseDownLocation = event.locationInWindow
            isDragging = false
            
            // Track clicks for double/triple click detection
            let now = Date()
            let timeSinceLastClick = now.timeIntervalSince(lastClickTime)
            
            // Reset click count if too much time has passed (> 0.5 seconds)
            if timeSinceLastClick > 0.5 {
                clickCount = 1
            } else {
                clickCount += 1
            }
            lastClickTime = now
            
        case .leftMouseDragged:
            // User is dragging - likely selecting text
            if mouseDownLocation != nil {
                let dragDistance = abs(event.locationInWindow.x - mouseDownLocation!.x) + 
                                  abs(event.locationInWindow.y - mouseDownLocation!.y)
                // Only consider it a drag if mouse moved more than 5 pixels
                if dragDistance > 5 {
                    isDragging = true
                }
            }
            
        case .leftMouseUp:
            // Check if CMD key is being held (user is likely copying)
            if event.modifierFlags.contains(.command) {
                print("📋 TextSelectionMonitor: CMD key held, skipping selection check (user likely copying)")
                mouseDownLocation = nil
                isDragging = false
                return
            }
            
            // Only check for selection if:
            // - User was dragging (selecting text)
            // - Shift key is held (extending selection)  
            // - Double/triple click (word/line selection)
            if isDragging || event.modifierFlags.contains(.shift) || clickCount >= 2 {
                if isDragging {
                    print("📋 TextSelectionMonitor: Detected drag selection")
                } else if clickCount >= 2 {
                    print("📋 TextSelectionMonitor: Detected double/triple click selection")
                } else {
                    print("📋 TextSelectionMonitor: Detected shift-click selection")
                }
                scheduleSelectionCheck()
            } else {
                // Single click - check if it deselected text (don't expect selection)
                print("📋 TextSelectionMonitor: Single click detected, checking if text was deselected")
                scheduleSelectionCheck(expectSelection: false)
            }
            
            // Reset tracking variables
            mouseDownLocation = nil
            isDragging = false
            
        default:
            break
        }
    }
    
    private func scheduleSelectionCheck(expectSelection: Bool = true) {
        // Cancel any existing timer
        selectionCheckTimer?.invalidate()
        
        // Don't check if already checking
        guard !isCheckingSelection else { return }
        
        // Check immediately for snappy response
        checkForSelectedText(expectSelection: expectSelection)
    }
    
    private func checkForSelectedText(expectSelection: Bool = true) {
        guard !isCheckingSelection else { return }
        isCheckingSelection = true
        
        // Use TextSelectionService to get selected text
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let currentSelectedText = TextSelectionService.shared.getSelectedText(expectSelection: expectSelection)
            
            DispatchQueue.main.async {
                self?.isCheckingSelection = false
                self?.handleSelectionResult(currentSelectedText)
            }
        }
    }
    
    private func handleSelectionResult(_ text: String?) {
        // Only process if selection has actually changed
        guard text != lastSelectedText else { return }
        
        print("📋 TextSelectionMonitor: Selection changed from '\(lastSelectedText?.prefix(20) ?? "nil")' to '\(text?.prefix(20) ?? "nil")'")
        
        lastSelectedText = text
        selectedText = text
        hasSelectedText = (text != nil && !text!.isEmpty)
        
        if hasSelectedText, let text = text {
            // Always show/update TTS HUD when we have selected text
            showTTSHUD(with: text)
        } else {
            // Text was deselected
            
            // Check if we're in the process of switching text
            if isSwitchingText {
                print("📋 TextSelectionMonitor: Text deselected while switching - clearing switch flag")
                isSwitchingText = false
                // Don't return - continue to hide HUD logic
            }
            
            // Check current TTS state
            let ttsState = TextToSpeechService.shared.state
            let isPlaying = TextToSpeechService.shared.isSpeaking
            print("📋 TextSelectionMonitor: Text deselected. TTS state: \(ttsState), isSpeaking: \(isPlaying)")
            
            // Hide HUD if TTS is not actively playing
            // Keep it visible only if TTS is actually playing audio
            if ttsState != .playing {
                print("📋 TextSelectionMonitor: TTS is not playing (state: \(ttsState)), will hide HUD")
                // Add a small delay to avoid race conditions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    // Double-check state hasn't changed
                    let currentState = TextToSpeechService.shared.state
                    print("📋 TextSelectionMonitor: Delayed check - state: \(currentState), hasSelectedText: \(self?.hasSelectedText ?? false)")
                    
                    // Hide if still not playing and no text selected
                    if currentState != .playing && self?.hasSelectedText == false {
                        print("📋 TextSelectionMonitor: Hiding HUD now")
                        self?.hideHUD()
                    } else {
                        print("📋 TextSelectionMonitor: Not hiding HUD - TTS started playing or text reselected")
                    }
                }
            } else {
                print("📋 TextSelectionMonitor: Text deselected but TTS is playing, keeping HUD visible")
            }
        }
    }
    
    private func showTTSHUD(with text: String) {
        print("📋 TextSelectionMonitor: Showing TTS HUD for text: \(text.prefix(50))...")
        
        // Check if we have an existing HUD controller
        let hasExistingController = hudController != nil
        let isHUDVisible = hudController?.window?.isVisible == true
        
        // Check if TTS is currently playing BEFORE we stop it
        let wasPlaying = TextToSpeechService.shared.state == .playing || TextToSpeechService.shared.state == .paused
        
        print("📋 TextSelectionMonitor: hasExistingController=\(hasExistingController), isHUDVisible=\(isHUDVisible), wasPlaying=\(wasPlaying)")
        
        // Set flag to indicate we're switching text
        if wasPlaying {
            isSwitchingText = true
        }
        
        // Play processing sound when selecting text (only if showing new HUD)
        if !isHUDVisible {
            HUDSoundEffects.shared.playProcessingSound()
        }
        
        // Stop current playback if playing
        if TextToSpeechService.shared.state == .playing {
            print("📋 TextSelectionMonitor: Stopping current TTS playback")
            TextToSpeechService.shared.stop()
        }
        
        // Update to new text
        TextToSpeechService.shared.currentText = text
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Always re-register observers to ensure we catch TTSDidFinish
            // Remove any existing observers first
            NotificationCenter.default.removeObserver(self, name: Notification.Name("TTSHUDDismissed"), object: nil)
            NotificationCenter.default.removeObserver(self, name: Notification.Name("TTSDidFinish"), object: nil)
            
            // Listen for dismiss notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleTTSHUDDismiss),
                name: Notification.Name("TTSHUDDismissed"),
                object: nil
            )
            
            // Listen for TTS finish notification to auto-dismiss
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.handleTTSDidFinish),
                name: Notification.Name("TTSDidFinish"),
                object: nil
            )
            
            // If we have an existing controller and it's visible, just reset it
            if let existingController = self.hudController, isHUDVisible {
                print("📋 TextSelectionMonitor: Resetting existing HUD for new text")
                existingController.resetForNewText()
            } else {
                // Need to create a new HUD
                print("📋 TextSelectionMonitor: Creating new TTS HUD")
                
                // Clear any existing controller reference
                self.hudController = nil
                
                // Create new TTS HUD
                let hudController = TTSHUDController()
                self.hudController = hudController
                hudController.showAnimated()
            }
            
            // Clear the switching flag after a delay (or immediately if not playing)
            if wasPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isSwitchingText = false
                }
            } else {
                // Clear immediately if wasn't playing
                self.isSwitchingText = false
            }
        }
    }
    
    private func hideHUD(force: Bool = false) {
        print("📋 TextSelectionMonitor: Hiding TTS HUD (force: \(force), isSwitchingText: \(isSwitchingText))")
        
        // Clear the switching flag when hiding
        isSwitchingText = false
        
        DispatchQueue.main.async { [weak self] in
            self?.hudController?.hideAnimated(isUserDismiss: force)
            self?.hudController = nil
        }
    }
    
    @objc private func handleTTSHUDDismiss() {
        print("📋 TextSelectionMonitor: TTS HUD dismissed")
        
        // Clear the HUD controller reference
        hudController = nil
        
        // Clear selection state
        selectedText = nil
        hasSelectedText = false
        lastSelectedText = nil
        
        // Remove observers
        NotificationCenter.default.removeObserver(self, name: Notification.Name("TTSHUDDismissed"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("TTSDidFinish"), object: nil)
    }
    
    @objc private func handleTTSDidFinish() {
        print("📋 TextSelectionMonitor: TTS finished playing, auto-dismissing HUD")
        
        // Auto-dismiss the HUD when TTS finishes
        hideHUD()
        
        // Clear selection state
        selectedText = nil
        hasSelectedText = false
        lastSelectedText = nil
        
        // Remove observers
        NotificationCenter.default.removeObserver(self, name: Notification.Name("TTSDidFinish"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("TTSHUDDismissed"), object: nil)
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
}