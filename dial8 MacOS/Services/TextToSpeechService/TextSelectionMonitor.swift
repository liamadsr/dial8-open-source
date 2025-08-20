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
    private let selectionCheckDelay: TimeInterval = 0.5 // Wait 500ms after mouse up to check selection
    private var hudController: TTSHUDController?
    private var isCheckingSelection = false
    
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
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseDown]) { [weak self] event in
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
    
    // MARK: - Private Methods
    
    private func handleMouseEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseUp:
            // User released mouse - might have selected text
            // Wait a bit then check for selection
            scheduleSelectionCheck()
        case .rightMouseDown:
            // Right click - might open context menu on selected text
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
        
        // Schedule a check after delay
        selectionCheckTimer = Timer.scheduledTimer(withTimeInterval: selectionCheckDelay, repeats: false) { [weak self] _ in
            self?.checkForSelectedText()
        }
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
        
        lastSelectedText = text
        selectedText = text
        hasSelectedText = (text != nil && !text!.isEmpty)
        
        print("📋 TextSelectionMonitor: Selection changed - hasText: \(hasSelectedText)")
        
        if hasSelectedText, let text = text {
            // Show TTS HUD
            showTTSHUD(with: text)
        } else {
            // Hide HUD if no text selected
            hideHUD()
        }
    }
    
    private func showTTSHUD(with text: String) {
        print("📋 TextSelectionMonitor: Showing TTS HUD for text: \(text.prefix(50))...")
        
        // Hide existing HUD if any
        hideHUD()
        
        // Create new TTS HUD
        DispatchQueue.main.async { [weak self] in
            let hudController = TTSHUDController()
            self?.hudController = hudController
            hudController.showAnimated()
            
            // Start speaking the text
            TextToSpeechService.shared.speak(text: text)
            
            // Listen for dismiss notification
            NotificationCenter.default.addObserver(
                self as Any,
                selector: #selector(self?.handleTTSHUDDismiss),
                name: Notification.Name("TTSHUDDismissed"),
                object: nil
            )
        }
    }
    
    private func hideHUD() {
        DispatchQueue.main.async { [weak self] in
            self?.hudController?.hideAnimated()
            self?.hudController = nil
        }
    }
    
    @objc private func handleTTSHUDDismiss() {
        print("📋 TextSelectionMonitor: TTS HUD dismissed")
        
        // Clear selection state
        selectedText = nil
        hasSelectedText = false
        lastSelectedText = nil
        
        // Remove observer
        NotificationCenter.default.removeObserver(self, name: Notification.Name("TTSHUDDismissed"), object: nil)
    }
    
    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
}