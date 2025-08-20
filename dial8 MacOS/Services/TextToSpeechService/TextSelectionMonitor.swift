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
    private let selectionCheckDelay: TimeInterval = 0.05 // Wait only 50ms after mouse up to check selection
    private var hudController: TTSHUDController?
    private var isCheckingSelection = false
    private var isSwitchingText = false // Flag to prevent auto-dismiss when switching text
    private var lastHUDActionTime: Date = Date.distantPast // Track last HUD show/hide to prevent rapid changes
    
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
        // Only monitor left mouse up (not right click to avoid interfering with context menus)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
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
        case .leftMouseUp:
            // User released mouse - might have selected text
            scheduleSelectionCheck()
        default:
            break
        }
    }
    
    private func scheduleSelectionCheck() {
        // Cancel any existing timer
        selectionCheckTimer?.invalidate()
        
        // Don't check if already checking
        guard !isCheckingSelection else { return }
        
        // Check immediately for faster response
        checkForSelectedText()
    }
    
    private func checkForSelectedText() {
        guard !isCheckingSelection else { return }
        isCheckingSelection = true
        
        // Use TextSelectionService to get selected text
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let currentSelectedText = TextSelectionService.shared.getSelectedText()
            
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
                print("📋 TextSelectionMonitor: Ignoring deselection - currently switching text")
                return
            }
            
            // Only hide HUD if TTS is not currently playing
            if TextToSpeechService.shared.state == .idle {
                // Add a small delay to avoid race conditions
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    // Double-check state hasn't changed
                    if TextToSpeechService.shared.state == .idle && self?.hasSelectedText == false {
                        self?.hideHUD()
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
        
        // Stop current playback if playing
        if TextToSpeechService.shared.state == .playing {
            print("📋 TextSelectionMonitor: Stopping current TTS playback")
            TextToSpeechService.shared.stop()
        }
        
        // Update to new text
        TextToSpeechService.shared.currentText = text
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
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
            }
            
            // Clear the switching flag after a delay
            if wasPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isSwitchingText = false
                }
            }
        }
    }
    
    private func hideHUD(force: Bool = false) {
        // Don't hide if we're switching text (unless forced)
        if !force && isSwitchingText {
            print("📋 TextSelectionMonitor: Skipping hide - currently switching text")
            return
        }
        
        print("📋 TextSelectionMonitor: Hiding TTS HUD (force: \(force))")
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