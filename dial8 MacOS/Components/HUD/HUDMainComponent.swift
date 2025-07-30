/*
 * HUDMainComponent.swift
 * 
 * PROPOSED RESTRUCTURING FOR EXTENSIBILITY:
 * 
 * 1. Component Structure:
 *    - HUDContainer (main container)
 *      ├─ IconSection (icon + animations)
 *      ├─ StatusSection (text + state)
 *      ├─ ControlsSection (buttons + interactions)
 *      ├─ DragDropZone (future)
 *      └─ ResizeHandles (future)
 * 
 * 2. State Management:
 *    - HUDState: Overall component state
 *    - AnimationState: Animation controls and states
 *    - LayoutState: Size and position management
 *    - InteractionState: Drag, resize, and interaction state
 * 
 * 3. Event System:
 *    - EventHandler: Central event management
 *    - Event types: Drag, Resize, Drop, Button clicks
 *    - Custom event handlers for specific interactions
 * 
 * 4. Layout System:
 *    - Dynamic sizing based on content
 *    - Flexible layout grid system
 *    - Responsive section management
 *    - Automatic constraint handling
 * 
 * 5. Future Extensions:
 *    - File drag & drop support
 *    - Dynamic content resizing
 *    - Additional control buttons
 *    - Text pass-through system
 *    - Enhanced visual feedback
 * 
 * This structure allows for:
 * - Easy addition of new features
 * - Independent component testing
 * - Better state management
 * - Flexible layouts
 * - Clear separation of concerns
 */

import Cocoa
import SwiftUI

// Add ViewHeightKey preference key definition
private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

class HUDMainController: NSWindowController {
    // Adjust constants to match native notifications
    private let animationDuration: TimeInterval = 0.3
    private let notificationWidth: CGFloat = HUDLayout.width
    private let notificationHeight: CGFloat = HUDLayout.height
    private let notificationPadding: CGFloat = 33  // Increased from 16 to 20 for more edge spacing
    private let notificationTopSpacing: CGFloat = 50
    
    private let cleanupDelay: TimeInterval = 30 // 3 seconds delay before cleanup
    private var isAnimating = false
    private var isWindowExpanded = false
    private var isLockedExpanded = false

    init(audioManager: AudioManager) {
        let window = HUDWindow()
        super.init(window: window)

        let contentView = HUDMainView(audioManager: audioManager)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16  // Match the pill-shaped corner radius
        hostingView.layer?.masksToBounds = true
        
        // Performance optimizations
        hostingView.layer?.shouldRasterize = true
        hostingView.layer?.rasterizationScale = window.backingScaleFactor
        
        window.contentView = hostingView
        
        // Set window properties to ensure it doesn't activate the app
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0
        
        // The canBecomeKey and canBecomeMain properties are already overridden in HUDWindow
        // Removing direct assignments that were causing errors
        
        // If this is an NSPanel, set additional properties
        if let panel = window as? NSPanel {
            panel.styleMask.insert(.nonactivatingPanel)
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
        }
        
        // Configure window with event handler
        if let interactionState = (hostingView.rootView as? HUDMainView)?.interactionState {
            window.configure(with: audioManager, interactionState: interactionState)
        }
        
        // Position HUD just above the dock
        if let screen = NSScreen.main {
            // The difference between screen.frame and screen.visibleFrame gives us the dock/menu bar areas
            let screenFrame = screen.frame
            let visibleFrame = screen.visibleFrame
            
            // Calculate dock height (when dock is at bottom)
            let dockHeight = visibleFrame.minY - screenFrame.minY
            
            // Add a small padding above the dock
            let paddingAboveDock: CGFloat = 10
            let bottomPadding = dockHeight + paddingAboveDock
            
            let xPos = screen.frame.midX - (HUDLayout.width / 2)
            let yPos = screen.frame.minY + bottomPadding
            window.setFrame(NSRect(x: xPos, y: yPos, width: HUDLayout.width, height: HUDLayout.height), display: true)
        }
        
        // Frame change observer removed - window is now fixed position
        
        // Observe recording lock state changes to resize window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recordingLockStateChanged(_:)),
            name: Notification.Name("RecordingLockedStateChanged"),
            object: nil
        )
        
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func positionWindow() {
        guard let window = self.window else { return }

        // Get the screen where the mouse is currently located
        var mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            let screenFrame = screen.frame

            let windowWidth: CGFloat = 220
            let windowHeight: CGFloat = 100

            let windowX = (screenFrame.width - windowWidth) / 2 + screenFrame.origin.x
            let windowY = screenFrame.maxY - windowHeight

            window.setFrame(NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight), display: true)
        }
    }

    func showAnimated() {
        print("HUDMainController: showAnimated called")
        guard let window = self.window else { return }
        
        // Position HUD just above the dock
        if let screen = NSScreen.main {
            // The difference between screen.frame and screen.visibleFrame gives us the dock/menu bar areas
            let screenFrame = screen.frame
            let visibleFrame = screen.visibleFrame
            
            // Calculate dock height (when dock is at bottom)
            let dockHeight = visibleFrame.minY - screenFrame.minY
            
            // Add a small padding above the dock
            let paddingAboveDock: CGFloat = 10
            let bottomPadding = dockHeight + paddingAboveDock
            
            let defaultX = screen.frame.midX - (notificationWidth / 2)
            let defaultY = screen.frame.minY + bottomPadding
            window.setFrame(NSRect(x: defaultX, y: defaultY, width: notificationWidth, height: notificationHeight), display: true)
        }
        
        // Start with window invisible to ensure animation controls visibility
        window.alphaValue = 0
        window.orderFrontRegardless()
        
        // Small delay to ensure window is ready before triggering animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Set window to full opacity - the SwiftUI view will control its own opacity
            window.alphaValue = 1
            
            // Trigger the folding open animation
            NotificationCenter.default.post(name: Notification.Name("HUDShouldAnimateIn"), object: nil)
        }
    }

    func hideAnimated() {
        print("Hiding HUD")
        guard !isAnimating else { return }
        isAnimating = true
        
        guard let window = self.window else { return }
        
        // Trigger the folding close animation
        NotificationCenter.default.post(name: Notification.Name("HUDShouldAnimateOut"), object: nil)
        
        // Wait for animation to complete before closing (match the animation duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            window.orderOut(nil)
            window.close()
            self.isAnimating = false
        }
    }

    @objc private func recordingLockStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isLocked = userInfo["isLocked"] as? Bool else { return }
        
        isLockedExpanded = isLocked
        resizeWindow(expanded: isLocked)
    }
    
    private func resizeWindow(expanded: Bool) {
        guard let window = self.window else { return }
        
        // Don't animate if already in the desired state
        if isWindowExpanded == expanded { return }
        
        isWindowExpanded = expanded
        
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let visibleFrame = screen.visibleFrame
            
            // Calculate dock height
            let dockHeight = visibleFrame.minY - screenFrame.minY
            let paddingAboveDock: CGFloat = 10
            let bottomPadding = dockHeight + paddingAboveDock
            
            // Calculate the new width
            let newWidth = expanded ? HUDLayout.expandedWidth : HUDLayout.width
            
            // Calculate x position to keep HUD centered
            let xPos = screen.frame.midX - (newWidth / 2)
            let yPos = screen.frame.minY + bottomPadding
            
            // Animate the frame change
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(
                    NSRect(x: xPos, y: yPos, width: newWidth, height: HUDLayout.height),
                    display: true
                )
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        print("HUDMainController: deinitialized")
    }

    override func close() {
        print("HUDMainController: close called")
        // Remove content view first to ensure cleanup of animations
        window?.contentView = nil
        window?.close()
        print("HUDMainController: window closed")
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = self.window,
              let screen = window.screen ?? NSScreen.main else { return }
        
        // Get the visible frame of the screen (accounts for Dock and Menu Bar)
        let screenFrame = screen.frame // Use full frame instead of visibleFrame
        var newFrame = window.frame
        
        // Constrain horizontally - allow a small portion to go off-screen
        let minVisibleWidth: CGFloat = 40 // Minimum width that must stay visible
        if newFrame.maxX > screenFrame.maxX + (newFrame.width - minVisibleWidth) {
            newFrame.origin.x = screenFrame.maxX - minVisibleWidth
        }
        if newFrame.minX < screenFrame.minX - (newFrame.width - minVisibleWidth) {
            newFrame.origin.x = screenFrame.minX - (newFrame.width - minVisibleWidth)
        }
        
        // Constrain vertically - allow full range of motion
        if newFrame.maxY > screenFrame.maxY {
            newFrame.origin.y = screenFrame.maxY - newFrame.height
        }
        if newFrame.minY < screenFrame.minY {
            newFrame.origin.y = screenFrame.minY
        }
        
        // Apply constraints if the frame changed
        if newFrame != window.frame {
            window.setFrame(newFrame, display: true)
        }
        
        // Save the window position
        saveWindowFrame(newFrame)
        
        // We no longer need to post a notification since we're using child windows
        // Child windows will automatically move with their parent
    }
    
    private func constrainFrameToScreen(_ frame: NSRect) -> NSRect {
        guard let screen = NSScreen.main else { return frame }
        
        let screenFrame = screen.frame // Use full frame instead of visibleFrame
        var newFrame = frame
        
        // Constrain horizontally - allow a small portion to go off-screen
        let minVisibleWidth: CGFloat = 40 // Minimum width that must stay visible
        if newFrame.maxX > screenFrame.maxX + (newFrame.width - minVisibleWidth) {
            newFrame.origin.x = screenFrame.maxX - minVisibleWidth
        }
        if newFrame.minX < screenFrame.minX - (newFrame.width - minVisibleWidth) {
            newFrame.origin.x = screenFrame.minX - (newFrame.width - minVisibleWidth)
        }
        
        // Constrain vertically - allow full range of motion
        if newFrame.maxY > screenFrame.maxY + newFrame.height {
            newFrame.origin.y = screenFrame.maxY
        }
        if newFrame.minY < screenFrame.minY - newFrame.height {
            newFrame.origin.y = screenFrame.minY - newFrame.height
        }
        
        return newFrame
    }
    
    private func saveWindowFrame(_ frame: NSRect) {
        let frameDict: [String: Any] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height,
            "screen": window?.screen?.localizedName ?? ""
        ]
        UserDefaults.standard.set(frameDict, forKey: "HUDWindowFrame")
    }
    
    private func getSavedWindowFrame() -> NSRect? {
        guard let frameDict = UserDefaults.standard.dictionary(forKey: "HUDWindowFrame"),
              let x = frameDict["x"] as? CGFloat,
              let y = frameDict["y"] as? CGFloat,
              let width = frameDict["width"] as? CGFloat,
              let height = frameDict["height"] as? CGFloat,
              let screenName = frameDict["screen"] as? String,
              let currentScreen = window?.screen,
              screenName == currentScreen.localizedName else {
            return nil
        }
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

public class HUDWindow: NSPanel {
    private var eventMonitor: Any?
    private var windowState: HUDWindowState!
    private var eventHandler: HUDEventHandler!
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: HUDLayout.width, height: HUDLayout.height),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        // Window behavior configuration
        self.isReleasedWhenClosed = true
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false  // We'll add our own shadow in SwiftUI
        self.becomesKeyOnlyIfNeeded = true
        self.titlebarAppearsTransparent = true
        self.hidesOnDeactivate = false
        
        // Ensure window doesn't activate the application
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        // The canBecomeKey and canBecomeMain properties are overridden below
        // Removing direct assignments that were causing errors
        
        // Make window fixed position
        self.ignoresMouseEvents = false
        self.isMovable = false
        self.isMovableByWindowBackground = false
        
        // Additional settings for independence
        self.displaysWhenScreenProfileChanges = true
        self.isExcludedFromWindowsMenu = true
        self.alphaValue = 1.0
        
        // Initialize window state manager
        self.windowState = HUDWindowState(window: self)
        
        // Setup event monitor
        // Disabled to allow button clicks to work properly
        // setupEventMonitor()
    }
    
    func configure(with audioManager: AudioManager, interactionState: HUDInteractionState) {
        // Initialize event handler
        self.eventHandler = HUDEventHandler(
            window: self,
            windowState: windowState,
            interactionState: interactionState,
            audioManager: audioManager
        )
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public override func makeKey() {
        // Do nothing to prevent the window from becoming key
    }
    
    public override func makeKeyAndOrderFront(_ sender: Any?) {
        self.orderFront(sender)
    }
    
    private func isClickInButtonArea(_ point: NSPoint) -> Bool {
        // Convert screen coordinates to window coordinates
        let windowPoint = self.convertPoint(fromScreen: point)
        return HUDLayout.buttonArea.contains(windowPoint)
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self = self, let eventHandler = self.eventHandler else { return event }
            
            let mouseLocation = NSEvent.mouseLocation
            
            switch event.type {
            case .leftMouseDown:
                // Always let the event through so all UI elements can receive clicks
                eventHandler.handleEvent(.mouseDown(mouseLocation))
                return event
                
            case .leftMouseDragged:
                eventHandler.handleEvent(.mouseDragged(mouseLocation))
                return nil
                
            case .leftMouseUp:
                eventHandler.handleEvent(.mouseUp(mouseLocation))
                return nil
                
            default:
                break
            }
            
            return event
        }
    }
}

struct HUDMainView: View {
    @ObservedObject private var audioManager: AudioManager
    @StateObject private var animationState = HUDAnimationState()
    @StateObject var interactionState = HUDInteractionState()
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var isRecordingLocked = false
    
    // Create a computed property to access the accumulated text via AudioTranscriptionService
    private var accumulatedText: String {
        AudioTranscriptionService.shared.accumulatedText
    }
    
    init(audioManager: AudioManager) {
        self._audioManager = ObservedObject(wrappedValue: audioManager)
    }
    
    var body: some View {
        // Main HUD content
        RoundedRectangle(cornerRadius: HUDLayout.cornerRadius)
            .fill(Color.black)
                .overlay(
                    // Thin gray outline that's always visible
                    RoundedRectangle(cornerRadius: HUDLayout.cornerRadius)
                        .stroke(Color(white: 0.6, opacity: 0.7), lineWidth: 1.2)
                )
                .overlay(
                    // Active state border - Siri-like gradient when speech detected
                    RoundedRectangle(cornerRadius: HUDLayout.cornerRadius)
                        .stroke(
                            audioManager.isSpeechDetected ? 
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.6, green: 0.2, blue: 1.0),  // Purple
                                        Color(red: 0.3, green: 0.8, blue: 1.0),  // Cyan
                                        Color(red: 0.2, green: 1.0, blue: 0.6),  // Green
                                        Color(red: 0.9, green: 0.3, blue: 0.8),  // Pink
                                        Color(red: 0.6, green: 0.2, blue: 1.0)   // Back to purple
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.clear]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: audioManager.isSpeechDetected ? 3 : 0
                        )
                        .padding(1) // Small padding to ensure border is fully visible
                )
                .overlay(
                    // Content - pass isHovering and isRecordingLocked to RecordingView
                    HUDStatusView.RecordingView(
                        audioManager: audioManager,
                        animationState: animationState,
                        interactionState: interactionState,
                        isHovering: isHovering,
                        isRecordingLocked: isRecordingLocked
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(
                    color: audioManager.isSpeechDetected ? 
                        Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.4) :  // Purple glow
                        Color.black.opacity(0.1),
                    radius: audioManager.isSpeechDetected ? 20 : 10,
                    x: 0,
                    y: 5
                )
                .onHover { hovering in
                    isHovering = hovering
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: audioManager.isSpeechDetected)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isRecordingLocked)
        .scaleEffect(x: 1, y: animationState.scaleY, anchor: .center)
        .rotation3DEffect(
            .degrees(animationState.rotationAngle),
            axis: (x: 1.0, y: 0.0, z: 0.0),
            anchor: .center,
            anchorZ: 0,
            perspective: animationState.perspectiveAmount
        )
        .opacity(animationState.opacity)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: audioManager.isSpeechDetected)
        .drawingGroup() // Optimize rendering performance
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HUDShouldAnimateIn"))) { _ in
            animationState.animateIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HUDShouldAnimateOut"))) { _ in
            animationState.animateOut {
                // Animation completed
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RecordingLockedStateChanged"))) { notification in
            if let userInfo = notification.userInfo,
               let isLocked = userInfo["isLocked"] as? Bool {
                isRecordingLocked = isLocked
            }
        }
    }
    
    private func calculateHeight() -> CGFloat {
        // Always return base height since we're only using streaming mode
        return HUDLayout.height
    }
}

