import Cocoa

/// Manages window state, positioning, and constraints for the HUD
class HUDWindowState: ObservableObject {
    // MARK: - Constants
    private let minVisibleWidth: CGFloat = 40
    private let defaultPosition = HUDPosition.topRight
    
    // MARK: - Published Properties
    @Published var currentFrame: NSRect
    @Published var isDragging: Bool = false
    
    // MARK: - Private Properties
    private weak var window: NSWindow?
    private var initialDragLocation: NSPoint?
    private var initialWindowLocation: NSPoint?
    
    // MARK: - Initialization
    init(window: NSWindow) {
        self.window = window
        self.currentFrame = window.frame
        
        // Restore saved position or use default
        if let savedFrame = getSavedWindowFrame() {
            self.currentFrame = savedFrame
            window.setFrame(savedFrame, display: true)
        } else {
            setDefaultPosition()
        }
        
        setupNotifications()
    }
    
    // MARK: - Window Position Management
    
    enum HUDPosition {
        case topLeft, topRight, bottomLeft, bottomRight, center
        
        func getFrame(for screen: NSScreen, size: NSSize, padding: CGFloat = 16) -> NSRect {
            let screenFrame = screen.frame
            var origin: NSPoint
            
            switch self {
            case .topRight:
                origin = NSPoint(
                    x: screenFrame.maxX - size.width - padding,
                    y: screenFrame.maxY - size.height - padding
                )
            case .topLeft:
                origin = NSPoint(
                    x: screenFrame.minX + padding,
                    y: screenFrame.maxY - size.height - padding
                )
            case .bottomRight:
                origin = NSPoint(
                    x: screenFrame.maxX - size.width - padding,
                    y: screenFrame.minY + padding
                )
            case .bottomLeft:
                origin = NSPoint(
                    x: screenFrame.minX + padding,
                    y: screenFrame.minY + padding
                )
            case .center:
                origin = NSPoint(
                    x: screenFrame.midX - size.width / 2,
                    y: screenFrame.midY - size.height / 2
                )
            }
            
            return NSRect(origin: origin, size: size)
        }
    }
    
    func setDefaultPosition() {
        guard let window = window,
              let screen = window.screen ?? NSScreen.main else { return }
        
        let newFrame = defaultPosition.getFrame(
            for: screen,
            size: NSSize(width: HUDLayout.width, height: HUDLayout.height)
        )
        
        window.setFrame(newFrame, display: true)
        currentFrame = newFrame
        saveWindowFrame(newFrame)
    }
    
    // MARK: - Frame Constraints
    
    func constrainFrame(_ frame: NSRect) -> NSRect {
        guard let screen = window?.screen ?? NSScreen.main else { return frame }
        
        let screenFrame = screen.frame
        var newFrame = frame
        
        // Constrain horizontally - allow a small portion to go off-screen
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
    
    // MARK: - Drag Handling
    
    func handleMouseDown(at point: NSPoint) -> Bool {
        guard let window = window else { return false }
        
        // If the point is in the window frame
        if window.frame.contains(point) {
            isDragging = true
            initialDragLocation = point
            initialWindowLocation = window.frame.origin
            return true
        }
        
        return false
    }
    
    func handleMouseDragged(to point: NSPoint) {
        guard isDragging,
              let initialDrag = initialDragLocation,
              let initialWindow = initialWindowLocation else { return }
        
        let deltaX = point.x - initialDrag.x
        let deltaY = point.y - initialDrag.y
        
        let newOrigin = NSPoint(
            x: initialWindow.x + deltaX,
            y: initialWindow.y + deltaY
        )
        
        let newFrame = NSRect(origin: newOrigin, size: currentFrame.size)
        let constrainedFrame = constrainFrame(newFrame)
        
        window?.setFrame(constrainedFrame, display: true)
        currentFrame = constrainedFrame
        saveWindowFrame(constrainedFrame)
    }
    
    func handleMouseUp() {
        isDragging = false
        initialDragLocation = nil
        initialWindowLocation = nil
    }
    
    // MARK: - Frame Persistence
    
    private func saveWindowFrame(_ frame: NSRect) {
        let frameDict = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(frameDict, forKey: "HUDWindowFrame")
    }
    
    private func getSavedWindowFrame() -> NSRect? {
        guard let frameDict = UserDefaults.standard.dictionary(forKey: "HUDWindowFrame"),
              let x = frameDict["x"] as? CGFloat,
              let y = frameDict["y"] as? CGFloat,
              let width = frameDict["width"] as? CGFloat,
              let height = frameDict["height"] as? CGFloat else {
            return nil
        }
        
        let frame = NSRect(x: x, y: y, width: width, height: height)
        return constrainFrame(frame)
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func handleScreenParametersChange() {
        guard let window = window else { return }
        
        // Ensure window is still visible on screen after display changes
        let constrainedFrame = constrainFrame(window.frame)
        if constrainedFrame != window.frame {
            window.setFrame(constrainedFrame, display: true)
            currentFrame = constrainedFrame
            saveWindowFrame(constrainedFrame)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 