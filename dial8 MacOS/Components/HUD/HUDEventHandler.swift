import SwiftUI

/// Manages all events for the HUD
class HUDEventHandler: ObservableObject {
    // MARK: - Event Types
    enum EventType {
        case mouseDown(NSPoint)
        case mouseDragged(NSPoint)
        case mouseUp(NSPoint)
        case mouseEntered(InteractionArea)
        case mouseExited(InteractionArea)
        case buttonClicked(ButtonType)
        case keyPressed(KeyType)
        case modeChanged(ModeType)
    }
    
    enum ButtonType {
        case close
        case minimize
    }
    
    enum KeyType {
        case escape
        case space
        case enter
    }
    
    enum ModeType {
        case stream
    }
    
    enum InteractionArea {
        case button
        case dragArea
        case iconArea
        case textArea
        case clearButton
        case copyButton
        case none
    }
    
    // MARK: - Dependencies
    private weak var window: NSWindow?
    private let windowState: HUDWindowState
    private let interactionState: HUDInteractionState
    private let audioManager: AudioManager
    
    // MARK: - Published Properties
    @Published var lastEvent: EventType?
    @Published var isProcessingEvent = false
    
    // MARK: - Event Monitors
    private var keyMonitor: Any?
    
    // MARK: - Initialization
    init(
        window: NSWindow,
        windowState: HUDWindowState,
        interactionState: HUDInteractionState,
        audioManager: AudioManager
    ) {
        self.window = window
        self.windowState = windowState
        self.interactionState = interactionState
        self.audioManager = audioManager
        
        setupKeyboardShortcuts()
    }
    
    // MARK: - Event Handling
    
    func handleEvent(_ event: EventType) {
        isProcessingEvent = true
        defer { isProcessingEvent = false }
        
        lastEvent = event
        
        switch event {
        case .mouseDown(let point):
            handleMouseDown(at: point)
            
        case .mouseDragged(let point):
            handleMouseDragged(to: point)
            
        case .mouseUp(let point):
            handleMouseUp(at: point)
            
        case .mouseEntered(let area):
            handleMouseEnter(convertToInteractionArea(area))
            
        case .mouseExited(let area):
            handleMouseExit(convertToInteractionArea(area))
            
        case .buttonClicked(let button):
            handleButtonClick(button)
            
        case .keyPressed(let key):
            handleKeyPress(key)
            
        case .modeChanged(let mode):
            handleModeChange(mode)
        }
    }
    
    // MARK: - Mouse Event Handlers
    
    private func handleMouseDown(at point: NSPoint) {
        if isInButtonArea(point) {
            // Let the button handle the click
            return
        }
        
        if windowState.handleMouseDown(at: point) {
            interactionState.handleMouseEnter(.dragArea)
        }
    }
    
    private func handleMouseDragged(to point: NSPoint) {
        if windowState.isDragging {
            windowState.handleMouseDragged(to: point)
        }
    }
    
    private func handleMouseUp(at point: NSPoint) {
        if windowState.isDragging {
            windowState.handleMouseUp()
            interactionState.handleMouseExit(.dragArea)
        }
    }
    
    // MARK: - Button Event Handlers
    
    private func handleButtonClick(_ button: ButtonType) {
        switch button {
        case .close:
            window?.close()
            
        case .minimize:
            window?.miniaturize(nil)
        }
    }
    
    // MARK: - Keyboard Event Handlers
    
    private func handleKeyPress(_ key: KeyType) {
        switch key {
        case .escape:
            window?.close()
        case .space:
            // No action needed for space key
            break
        case .enter:
            // Handle enter key
            break
        }
    }
    
    // MARK: - Mode Event Handlers
    
    private func handleModeChange(_ mode: ModeType) {
        // Always in streaming mode now, no action needed
    }
    
    // MARK: - Helper Methods
    
    private func isInButtonArea(_ point: NSPoint) -> Bool {
        guard let window = window else { return false }
        let windowPoint = window.convertPoint(fromScreen: point)
        return HUDLayout.buttonArea.contains(windowPoint)
    }
    
    private func handleMouseEnter(_ area: HUDInteractionState.InteractionArea) {
        switch area {
        case .modeButton:
            interactionState.handleMouseEnter(.modeButton)
            NSCursor.pointingHand.push()
        case .dragArea:
            interactionState.handleMouseEnter(.dragArea)
            NSCursor.openHand.push()
        case .iconArea:
            interactionState.handleMouseEnter(.iconArea)
            NSCursor.pointingHand.push()
        case .textArea:
            interactionState.handleMouseEnter(.textArea)
        case .clearButton, .clearButtonBackground:
            interactionState.handleMouseEnter(.clearButton)
            NSCursor.pointingHand.push()
        case .copyButton, .copyButtonBackground:
            interactionState.handleMouseEnter(.copyButton)
            NSCursor.pointingHand.push()
        case .none:
            break
        }
    }
    
    private func handleMouseExit(_ area: HUDInteractionState.InteractionArea) {
        switch area {
        case .modeButton:
            interactionState.handleMouseExit(.modeButton)
            NSCursor.pop()
        case .dragArea:
            interactionState.handleMouseExit(.dragArea)
            NSCursor.pop()
        case .iconArea:
            interactionState.handleMouseExit(.iconArea)
            NSCursor.pop()
        case .textArea:
            interactionState.handleMouseExit(.textArea)
        case .clearButton, .clearButtonBackground:
            interactionState.handleMouseExit(.clearButton)
            NSCursor.pop()
        case .copyButton, .copyButtonBackground:
            interactionState.handleMouseExit(.copyButton)
            NSCursor.pop()
        case .none:
            break
        }
    }
    
    private func convertToInteractionArea(_ area: InteractionArea) -> HUDInteractionState.InteractionArea {
        switch area {
        case .button:
            return .modeButton
        case .dragArea:
            return .dragArea
        case .iconArea:
            return .iconArea
        case .textArea:
            return .textArea
        case .clearButton:
            return .clearButton
        case .copyButton:
            return .copyButton
        case .none:
            return .none
        }
    }
    
    // MARK: - Keyboard Shortcuts
    
    private func setupKeyboardShortcuts() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                // ESC key
                case 53:
                    self.handleEvent(.keyPressed(.escape))
                    return nil
                    
                // Space key
                case 49:
                    // Don't intercept Command+Space (allow Spotlight)
                    return event
                    
                // Enter key
                case 36:
                    self.handleEvent(.keyPressed(.enter))
                    return nil
                    
                default:
                    break
                }
            }
            
            return event
        }
    }
    
    // MARK: - Cleanup
    
    func invalidate() {
        // Clean up any observers or monitors
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    deinit {
        invalidate()
    }
} 