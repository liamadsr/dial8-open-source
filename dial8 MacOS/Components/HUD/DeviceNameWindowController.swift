import Cocoa
import SwiftUI

class DeviceNameWindowController: NSWindowController {
    private var hideTimer: Timer?
    
    init(deviceName: String, parentWindow: NSWindow?) {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 68),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        // Configure window
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating + 1  // Above the HUD
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isMovable = false
        window.hidesOnDeactivate = false
        
        // Create content view
        let contentView = DeviceNameView(deviceName: deviceName)
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        
        // Position above parent window or at default position
        positionWindow(above: parentWindow)
        
        // Show with animation
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
        
        // Auto-hide after 3 seconds
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hideAnimated()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func positionWindow(above parentWindow: NSWindow?) {
        guard let window = self.window else { return }
        
        if let parent = parentWindow {
            // Position above the parent window
            let parentFrame = parent.frame
            let spacing: CGFloat = 10
            let x = parentFrame.midX - (window.frame.width / 2)
            let y = parentFrame.maxY + spacing
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            // Default position (center of screen, upper third)
            if let screen = NSScreen.main {
                let x = screen.frame.midX - (window.frame.width / 2)
                let y = screen.frame.midY + 100
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
    
    func hideAnimated() {
        hideTimer?.invalidate()
        guard let window = self.window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        }) { [weak self] in
            window.orderOut(nil)
            self?.close()
        }
    }
    
    deinit {
        hideTimer?.invalidate()
    }
}

struct DeviceNameView: View {
    let deviceName: String
    @State private var showContent = false
    
    var deviceIcon: String {
        let lowercaseName = deviceName.lowercased()
        if lowercaseName.contains("airpods") {
            return "🎧"
        } else if lowercaseName.contains("headphone") || lowercaseName.contains("headset") {
            return "🎧"
        } else if lowercaseName.contains("macbook") || lowercaseName.contains("built-in") {
            return "💻"
        } else if lowercaseName.contains("usb") || lowercaseName.contains("microphone") {
            return "🎤"
        } else if lowercaseName.contains("display") || lowercaseName.contains("monitor") {
            return "🖥️"
        } else {
            return "🔊"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with circular background
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Text(deviceIcon)
                    .font(.system(size: 22))
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                // First line: Action text
                Text("Input change detected")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                
                // Second line: Device name
                Text("Switching to \(deviceName)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)  // Match HUD corner radius
                .fill(Color.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .scaleEffect(showContent ? 1 : 0.9)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }
}