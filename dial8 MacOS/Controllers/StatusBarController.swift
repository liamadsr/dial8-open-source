import SwiftUI
import AppKit

class StatusBarController: NSObject, ObservableObject {
    private var statusBar: NSStatusBar?
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    @ObservedObject var audioManager: AudioManager
    
    private var settingsItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var settingsWindowController: NSWindowController?
    
    private var appDelegate: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }
    
    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        super.init()
        DispatchQueue.main.async { [weak self] in
            self?.setupStatusBar()
        }
    }
    
    private func setupStatusBar() {
        statusBar = NSStatusBar.system
        statusItem = statusBar?.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        setupStatusBarButton()
        setupMenu()
    }
    
    private func setupStatusBarButton() {
        if let statusBarButton = statusItem?.button {
            // Load the custom icon
            if let icon = NSImage(named: "StatusBarIcon") {
                // Ensure it's treated as a template image
                icon.isTemplate = true
                // Set the icon size to 16x16 for proper status bar fit
                icon.size = NSSize(width: 16, height: 16)
                statusBarButton.image = icon
            }
            
            // Set action to directly open settings when clicked
            statusBarButton.action = #selector(openSettings(_:))
            statusBarButton.target = self
            
            // Enable right-click detection
            statusBarButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupMenu() {
        // Remove menu setup - we're now opening settings directly on click
        statusItem?.menu = nil
    }
    
    
    @objc func openSettings(_ sender: Any?) {
        // Check if it's a right-click
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            // Show context menu on right-click
            showContextMenu()
        } else {
            // Left-click - open settings
            Task { @MainActor in
                // Check if settings window already exists
                if let existingWindow = settingsWindow {
                    // Window exists, bring it to front
                    existingWindow.makeKeyAndOrderFront(nil)
                    existingWindow.orderFrontRegardless()
                    
                    // If window is minimized, deminiaturize it
                    if existingWindow.isMiniaturized {
                        existingWindow.deminiaturize(nil)
                    }
                    
                    // Ensure window is visible
                    if !existingWindow.isVisible {
                        existingWindow.orderFront(nil)
                    }
                    
                    // Force app activation with more aggressive settings
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.arrangeInFront(nil)
                    existingWindow.level = .floating
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        existingWindow.level = .normal
                    }
                    
                    return
                }
                
                // Create new window only if it doesn't exist
                let windowManager = WindowManager()
                let contentView = ContentView()
                    .environmentObject(windowManager)
                    .environmentObject(self.audioManager)
                let hostingController = NSHostingController(rootView: contentView)
                let window = NSWindow(contentViewController: hostingController)
                window.title = ""
                window.setContentSize(NSSize(width: 1000, height: 700))
                window.minSize = NSSize(width: 800, height: 500)
                window.center()
                
                // Configure window style
                window.backgroundColor = NSColor.windowBackgroundColor
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                
                // Set delegate to handle window closing
                window.delegate = self
                
                // Store reference to the window
                settingsWindow = window
                
                // Create window controller to keep window alive
                let windowController = NSWindowController(window: window)
                settingsWindowController = windowController
                
                windowController.showWindow(nil)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
                NSApp.arrangeInFront(nil)
                
                // Temporarily set floating level to ensure it comes to front
                window.level = .floating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    window.level = .normal
                }
            }
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        // Add Quit menu item
        let quitItem = NSMenuItem(title: "Quit Dial8", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Show the menu
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        
        // Remove the menu after showing to restore normal left-click behavior
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSWindowDelegate
extension StatusBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Clear the window reference when it closes
        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
            settingsWindowController = nil
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow the window to close
        return true
    }
}
