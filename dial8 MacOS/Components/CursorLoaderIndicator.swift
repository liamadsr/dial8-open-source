import Cocoa
import SwiftUI

class CursorLoaderIndicatorWindowController: NSWindowController {
    init(at point: CGPoint) {
        // Create a small window for the indicator
        let size = CGSize(width: 40, height: 24)
        
        // Position slightly above the cursor
        let position = CGPoint(
            x: point.x - size.width / 2,
            y: point.y + 15
        )
        
        // Create a borderless window
        let window = NSWindow(
            contentRect: NSRect(origin: position, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        // Configure window properties
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating + 2
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Set up the loading indicator view
        let contentView = LoadingDotsView()
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        window?.orderFront(nil)
    }
    
    func hide() {
        window?.orderOut(nil)
    }
}

private struct LoadingDotsView: View {
    @State private var dotCount = 1
    
    let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(String(repeating: ".", count: dotCount))
            .foregroundColor(.gray)
            .font(.system(size: 24, weight: .bold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(timer) { _ in
                dotCount = dotCount % 3 + 1
            }
    }
}
