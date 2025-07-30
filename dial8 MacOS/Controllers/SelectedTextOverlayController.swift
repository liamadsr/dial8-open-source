import Cocoa
import SwiftUI

// Custom panel class that overrides the key window behavior
class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    override func makeKey() {
        // Do nothing to prevent the window from becoming key
    }
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        // Just order front without making key
        self.orderFront(sender)
    }
}

class SelectedTextOverlayController: NSWindowController {
    // Use SelectedTextOverlay layout constants
    private let overlayWidth: CGFloat = HUDLayout.SelectedTextOverlay.width
    private let overlayHeight: CGFloat = 180  // This is still custom as it needs to be taller than the HUD
    private let overlayTopSpacing: CGFloat = HUDLayout.SelectedTextOverlay.spacing
    
    private var isAnimating = false
    private weak var hudWindow: NSWindow?
    
    // Add selectedText property
    let selectedText: String
    
    init(selectedText: String) {
        self.selectedText = selectedText
        let panel = NonActivatingPanel()
        super.init(window: panel)
        
        print("🔍 SelectedTextOverlayController: Creating window with text: \(selectedText.prefix(20))...")
        
        // Configure window to match HUD styling and ensure non-activation
        panel.styleMask = [.nonactivatingPanel, .borderless]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = true
        // Ensure window level is high enough to be visible but doesn't activate
        panel.level = NSWindow.Level.floating + 10
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
        // Create content view
        let contentView = SelectedTextView(text: selectedText)
        let hostingView = NSHostingView(rootView: contentView)
        panel.contentView = hostingView
        
        // Set the frame size using overlay dimensions
        panel.setFrame(NSRect(x: 0, y: 0, width: overlayWidth, height: overlayHeight), display: false)
        
        // Apply corner radius to match SelectedTextOverlay
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = HUDLayout.SelectedTextOverlay.cornerRadius
        panel.contentView?.layer?.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // Make sure we detach from parent window before deallocating
        detachFromHUD()
    }
    
    func attachToHUD(hudWindow: NSWindow) {
        guard let overlayWindow = self.window else { return }
        
        // Store reference to HUD window
        self.hudWindow = hudWindow
        
        // Set up child window relationship
        hudWindow.addChildWindow(overlayWindow, ordered: .above)
        
        print("🔍 SelectedTextOverlayController: Attached to HUD window as child")
    }
    
    func detachFromHUD() {
        guard let overlayWindow = self.window,
              let hudWindow = self.hudWindow else { return }
        
        // Remove child window relationship
        hudWindow.removeChildWindow(overlayWindow)
        print("🔍 SelectedTextOverlayController: Detached from HUD window")
    }
    
    func showAboveHUD(hudFrame: NSRect) {
        guard let window = self.window else { 
            print("❌ SelectedTextOverlayController: No window to show")
            return 
        }
        
        // Position above the HUD
        let xPos = hudFrame.origin.x
        // Make sure the y position is high enough to be visible
        let yPos = hudFrame.origin.y + hudFrame.height + overlayTopSpacing
        
        // Check if the position is on screen
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        print("🔍 SelectedTextOverlayController: Screen frame: \(screenFrame)")
        
        let windowFrame = NSRect(x: xPos, y: yPos, width: overlayWidth, height: overlayHeight)
        print("🔍 SelectedTextOverlayController: Setting window frame to: \(windowFrame)")
        
        window.setFrame(windowFrame, display: true)
        
        // Ensure it's front-most without activating the app
        window.orderFrontRegardless()
        
        // If we're a child window, no need to set position again as it will move with the parent
        // But we still need to show it
        if let hudWindow = hudWindow {
            let isAlreadyChild = hudWindow.childWindows?.contains(window) == true
            if !isAlreadyChild {
                attachToHUD(hudWindow: hudWindow)
            }
        }
        
        // Reset alpha to make sure it's fully visible
        window.alphaValue = 0
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1.0
        }, completionHandler: {
            print("🔍 SelectedTextOverlayController: Animation completed, alpha now: \(window.alphaValue)")
        })
    }
    
    func hideAnimated() {
        guard let window = self.window, !isAnimating else { 
            print("❌ SelectedTextOverlayController: No window to hide or already animating")
            return 
        }
        
        isAnimating = true
        print("🔍 SelectedTextOverlayController: Hiding window with animation")
        
        // Detach from HUD window first
        detachFromHUD()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.isAnimating = false
            print("🔍 SelectedTextOverlayController: Window hidden")
        })
    }
} 
