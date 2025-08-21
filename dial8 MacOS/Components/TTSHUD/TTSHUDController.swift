import Cocoa
import SwiftUI

class TTSHUDWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: HUDLayout.expandedWidth, height: HUDLayout.height),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        // Window configuration
        self.isReleasedWhenClosed = true
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.becomesKeyOnlyIfNeeded = true
        self.titlebarAppearsTransparent = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.isMovable = false
        self.isMovableByWindowBackground = false
    }
    
    // Don't allow window to become key - this prevents interference with copy/paste
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class TTSHUDController: NSWindowController {
    private let animationDuration: TimeInterval = 0.3
    private var isAnimating = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hasStartedPlaying = false
    
    init() {
        let window = TTSHUDWindow()
        super.init(window: window)
        
        let contentView = TTSHUDView(onDismiss: { [weak self] in
            self?.hideAnimated(isUserDismiss: true)
        })
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = HUDLayout.cornerRadius
        hostingView.layer?.masksToBounds = true
        
        window.contentView = hostingView
        window.alphaValue = 0
        
        // Position HUD at bottom of screen, similar to recording HUD
        positionWindow()
        
        // Setup key event monitoring for space key
        setupKeyEventMonitor()
    }
    
    private func setupKeyEventMonitor() {
        // Create event tap callback
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // Define the callback function
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
            // Get the controller instance from refcon
            let controller = Unmanaged<TTSHUDController>.fromOpaque(refcon!).takeUnretainedValue()
            
            // Check if it's a key down event
            if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                
                // Check if space key (49) without modifiers
                if keyCode == 49 &&
                   !flags.contains(.maskCommand) &&
                   !flags.contains(.maskAlternate) &&
                   !flags.contains(.maskControl) &&
                   controller.window?.isVisible == true {
                    
                    // If we haven't started playing yet, consume this space press
                    if !controller.hasStartedPlaying {
                        controller.hasStartedPlaying = true
                        
                        // Start TTS on main thread
                        DispatchQueue.main.async {
                            if let text = TextToSpeechService.shared.currentText {
                                print("🔊 TTSHUDController: Starting TTS playback via space key (consuming event)")
                                TextToSpeechService.shared.speak(text: text)
                            }
                        }
                        
                        // Consume the event by returning nil
                        return nil
                    }
                }
            }
            
            // Pass through all other events
            return Unmanaged.passUnretained(event)
        }
        
        // Create the event tap
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        // Add to run loop if tap was created successfully
        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("🔊 TTSHUDController: Event tap installed successfully")
        } else {
            print("🔊 TTSHUDController: Failed to create event tap - may need accessibility permissions")
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func positionWindow() {
        guard let window = self.window, let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // Calculate dock height
        let dockHeight = visibleFrame.minY - screenFrame.minY
        let paddingAboveDock: CGFloat = 10
        let bottomPadding = dockHeight + paddingAboveDock
        
        // Position at exact same spot as recording HUD (using expanded width)
        let xPos = screen.frame.midX - (HUDLayout.expandedWidth / 2)
        let yPos = screen.frame.minY + bottomPadding
        
        window.setFrame(NSRect(x: xPos, y: yPos, width: HUDLayout.expandedWidth, height: HUDLayout.height), display: true)
    }
    
    func showAnimated() {
        guard let window = self.window else { return }
        
        // Reset the playing flag so space key works for new selection
        hasStartedPlaying = false
        
        // Start with window invisible to ensure animation controls visibility
        window.alphaValue = 0
        window.orderFrontRegardless()
        // Don't make window key - this prevents interference with copy/paste
        
        // Small delay to ensure window is ready before triggering animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Set window to full opacity - the SwiftUI view will control its own opacity
            window.alphaValue = 1
            
            // Trigger the folding open animation
            NotificationCenter.default.post(name: Notification.Name("TTSHUDShouldAnimateIn"), object: nil)
            
            print("🔊 TTSHUDController: Window shown with animation and ready for input")
        }
    }
    
    func resetForNewText() {
        // Reset the playing flag so space key works for new selection
        hasStartedPlaying = false
        
        // Make sure window is visible but don't make it key
        if let window = self.window {
            // Ensure window stays visible
            if !window.isVisible {
                window.orderFrontRegardless()
            }
            // Don't make window key - this prevents interference with copy/paste
            
            // Force the SwiftUI view to update by triggering a small UI refresh
            if let hostingView = window.contentView as? NSHostingView<TTSHUDView> {
                // The view will automatically update when TTS service state changes
                print("🔊 TTSHUDController: Reset for new text selection, window visible: \(window.isVisible)")
            }
        }
    }
    
    func hideAnimated(isUserDismiss: Bool = false) {
        guard let window = self.window, !isAnimating else { return }
        
        print("🔊 TTSHUDController: hideAnimated called, isUserDismiss: \(isUserDismiss)")
        
        isAnimating = true
        
        // Stop TTS playback when HUD is dismissed
        if TextToSpeechService.shared.state != .idle {
            print("🔊 TTSHUDController: Stopping TTS playback on HUD dismiss")
            TextToSpeechService.shared.stop()
        }
        
        // Immediately clean up key event monitors before animation starts
        // This prevents the "not allowed" sound when dismissing
        cleanupKeyMonitors()
        
        // Trigger the folding close animation
        NotificationCenter.default.post(name: Notification.Name("TTSHUDShouldAnimateOut"), object: nil)
        
        // Wait for animation to complete before closing (match the animation duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            window.orderOut(nil)
            window.close()
            self?.isAnimating = false
            self?.hasStartedPlaying = false
            
            // Post notification that TTS HUD was dismissed
            NotificationCenter.default.post(name: Notification.Name("TTSHUDDismissed"), object: nil)
        }
    }
    
    private func cleanupKeyMonitors() {
        // Disable and remove event tap
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        
        // Remove from run loop
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }
    
    deinit {
        // Stop TTS if still playing
        if TextToSpeechService.shared.state != .idle {
            TextToSpeechService.shared.stop()
        }
        
        // Clean up key event monitors
        cleanupKeyMonitors()
    }
}