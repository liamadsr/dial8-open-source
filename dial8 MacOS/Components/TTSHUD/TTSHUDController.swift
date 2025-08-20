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
    
    // Allow window to become key to receive key events
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

class TTSHUDController: NSWindowController {
    private let animationDuration: TimeInterval = 0.3
    private var isAnimating = false
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
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
        // Use global monitor to capture space key before it reaches other apps
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            // Check if space key was pressed (keyCode 49) and window is visible
            if event.keyCode == 49 && !self.hasStartedPlaying && self.window?.isVisible == true {
                self.hasStartedPlaying = true
                
                // Start TTS if we have text
                if let text = TextToSpeechService.shared.currentText {
                    print("🔊 TTSHUDController: Starting TTS playback via space key")
                    TextToSpeechService.shared.speak(text: text)
                }
            }
        }
        
        // Also add local monitor to consume the space key event
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Only process if window is visible and key window
            guard let window = self.window,
                  window.isVisible && window.isKeyWindow else {
                return event
            }
            
            // Consume space key if we haven't started playing
            if event.keyCode == 49 {
                if !self.hasStartedPlaying {
                    self.hasStartedPlaying = true
                    
                    // Start TTS if we have text
                    if let text = TextToSpeechService.shared.currentText {
                        print("🔊 TTSHUDController: Starting TTS playback via space key (local)")
                        TextToSpeechService.shared.speak(text: text)
                    }
                }
                // Consume the event to prevent it from reaching other apps
                return nil
            }
            
            return event
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
        
        window.orderFrontRegardless()
        window.makeKey()  // Make window key to receive key events
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1
        }, completionHandler: {
            print("🔊 TTSHUDController: Window shown and ready for input")
        })
    }
    
    func resetForNewText() {
        // Reset the playing flag so space key works for new selection
        hasStartedPlaying = false
        
        // Make sure window is visible and key to receive events
        if let window = self.window {
            // Ensure window stays visible
            if !window.isVisible {
                window.orderFrontRegardless()
            }
            window.makeKey()
            
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
        
        // Resign key window status to prevent key event issues
        if window.isKeyWindow {
            window.resignKey()
        }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            window.close()
            self?.isAnimating = false
            self?.hasStartedPlaying = false
            
            // Post notification that TTS HUD was dismissed
            NotificationCenter.default.post(name: Notification.Name("TTSHUDDismissed"), object: nil)
        })
    }
    
    private func cleanupKeyMonitors() {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
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