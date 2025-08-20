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
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class TTSHUDController: NSWindowController {
    private let animationDuration: TimeInterval = 0.3
    private var isAnimating = false
    
    init() {
        let window = TTSHUDWindow()
        super.init(window: window)
        
        let contentView = TTSHUDView(onDismiss: { [weak self] in
            self?.hideAnimated()
        })
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = HUDLayout.cornerRadius
        hostingView.layer?.masksToBounds = true
        
        window.contentView = hostingView
        window.alphaValue = 0
        
        // Position HUD at bottom of screen, similar to recording HUD
        positionWindow()
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
        
        window.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1
        })
    }
    
    func hideAnimated() {
        guard let window = self.window, !isAnimating else { return }
        
        isAnimating = true
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            window.close()
            self?.isAnimating = false
            
            // Post notification that TTS HUD was dismissed
            NotificationCenter.default.post(name: Notification.Name("TTSHUDDismissed"), object: nil)
        })
    }
}