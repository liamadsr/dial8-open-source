import SwiftUI

#if DEVELOPMENT
import Foundation // This import is not necessary if you're not using any Foundation types directly
#endif

// Add at the top of the file, outside the main app struct
extension View {
    func logView(_ message: String) -> some View {
        print("📱 APP VIEW: \(message)")
        return self
    }
}

// Add a logging utility
private func log(_ message: String) {
    print("📱 APP: \(message)")
}

// Add before the main app struct
@MainActor
private final class InitializationManager: ObservableObject {
    @Published private(set) var isInitialized = false
    
    func markAsInitialized() {
        isInitialized = true
    }
}

// Main entry point for the ThinkingAloud application
@main
struct ThinkingAloudApp: App {
    // Use the appropriate application delegate based on the platform
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    // Core managers for the application
    private let windowManager: WindowManager
    
    // macOS-specific controllers
    #if os(macOS)
    private let statusBarController: StatusBarController
    private let hotkeyManager: GlobalHotkeyManager
    private let audioManager: AudioManager
    #endif

    // Development mode settings
    #if DEVELOPMENT
    @AppStorage("devModeEnabled") private var devModeEnabled = false
    @AppStorage("showOnboardingInDevMode") private var showOnboardingInDevMode = false
    #endif

    // State to control onboarding display
    @State private var showOnboarding: Bool
    @State private var hasCreatedWindow = false

    // Replace the isInitialized state with a StateObject
    @StateObject private var initManager = InitializationManager()

    // Initialize the application and its core components
    init() {
        log("Starting app initialization")
        
        // First, handle fresh install simulation before creating any managers
        if UserDefaults.standard.bool(forKey: "simulateFirstLaunch") {
            log("Simulating fresh install")
            let bundleId = Bundle.main.bundleIdentifier!
            
            // Clear UserDefaults
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.synchronize()
            
            // Clear cache directory
            if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                try? FileManager.default.removeItem(at: cacheURL)
            }
            
            // Clear Application Support directory
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent(bundleId) {
                try? FileManager.default.removeItem(at: appSupportURL)
            }
            
            // Clear Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: bundleId
            ]
            SecItemDelete(query as CFDictionary)
            
            // Reset permissions state
            UserDefaults.standard.hasCompletedOnboarding = false
            UserDefaults.standard.removeObject(forKey: "microphonePermissionGranted")
            UserDefaults.standard.removeObject(forKey: "accessibilityPermissionGranted")
            
            // Set default values for settings
            UserDefaults.standard.set(false, forKey: "streamingModeEnabled")  // Set block mode as default
            
            // Ensure dev setting onboarding is shown
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(true, forKey: "showOnboardingInDevMode")
            
            // Ensure the flag stays set for next launch
            UserDefaults.standard.set(true, forKey: "simulateFirstLaunch")
        }

        log("Initializing core managers")
        // Initialize core managers
        let authManager = AuthenticationManager.shared
        let windowManager = WindowManager()
        
        // Initialize macOS-specific components
        #if os(macOS)
        let audioManager = AudioManager()
        let statusBarController = StatusBarController(
            audioManager: audioManager
        )
        let hotkeyManager = GlobalHotkeyManager(
            windowManager: windowManager,
            statusBarController: statusBarController,
            audioManager: audioManager
        )
        #endif

        // Assign to stored properties
        self.windowManager = windowManager
        #if os(macOS)
        self.audioManager = audioManager
        #endif
        
        #if os(macOS)
        self.statusBarController = statusBarController
        self.hotkeyManager = hotkeyManager
        #endif

        // Initialize showOnboarding state
        self._showOnboarding = State(initialValue: false)

        // Ensure default settings are set
        ensureDefaultSettings()

        log("Initialization complete")
    }
    
    private func waitForInitialization() async {
        // Wait for WhisperManager to be ready
        await WhisperManager.shared.waitUntilReady()
        
        // Wait for audio engine to be ready
        #if os(macOS)
        await hotkeyManager.audioManager.waitUntilReady()
        
        // Add a final check of the hotkey system
        let manager = hotkeyManager // Capture the reference
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Reset the event tap to ensure clean state after initialization
            manager.resetEventTap()
        }
        #endif
        
        // Mark initialization as complete
        await initManager.markAsInitialized()
    }

    // MARK: - Default Settings
    
    private func ensureDefaultSettings() {
        // Set default value for streaming mode if it doesn't exist (block mode by default)
        if !UserDefaults.standard.contains(key: "streamingModeEnabled") {
            UserDefaults.standard.set(false, forKey: "streamingModeEnabled")
        }
    }

    // Define the app's user interface and behavior
    var body: some Scene {
        #if os(macOS)
        // On macOS, we only want menu bar functionality, no main window
        Settings {
            EmptyView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove default menu items we don't want
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
        }
        #else
        WindowGroup {
            Group {
                if !initManager.isInitialized {
                    InitializationLoadingView()
                } else {
                    #if DEVELOPMENT
                    if devModeEnabled && showOnboardingInDevMode {
                        OnboardingView()
                            .overlay(DevModeOverlay(showControls: true), alignment: .topTrailing)
                            .logView("Showing OnboardingView (Dev Mode)")
                    } else if !UserDefaults.standard.hasCompletedOnboarding {
                        // First-time users always see OnboardingView
                        OnboardingView()
                            .overlay(DevModeOverlay(showControls: false), alignment: .topTrailing)
                            .logView("Showing OnboardingView (First-time User)")
                    } else {
                        // Show ContentView
                        ContentView()
                            .environmentObject(windowManager)
                            .onAppear {
                                log("ContentView appeared")
                                requestMicrophonePermission()
                            }
                            .logView("Showing ContentView")
                    }
                    #else
                    if !UserDefaults.standard.hasCompletedOnboarding {
                        OnboardingView()
                    } else {
                        // Show ContentView
                        ContentView()
                            .environmentObject(windowManager)
                            .onAppear {
                                requestMicrophonePermission()
                            }
                    }
                    #endif
                }
            }
            .frame(minWidth: AppConfig.WindowDimensions.minWidth, 
                   idealWidth: AppConfig.WindowDimensions.idealWidth, 
                   maxWidth: AppConfig.WindowDimensions.maxWidth,
                   minHeight: AppConfig.WindowDimensions.minHeight, 
                   idealHeight: AppConfig.WindowDimensions.idealHeight, 
                   maxHeight: AppConfig.WindowDimensions.maxHeight)
            .onAppear {
                log("Main window appeared")
                // Set the initial value for showOnboarding
                #if DEVELOPMENT
                self.showOnboarding = UserDefaults.standard.bool(forKey: "showOnboardingInDevMode") || 
                                      !UserDefaults.standard.hasCompletedOnboarding
                #else
                self.showOnboarding = !UserDefaults.standard.hasCompletedOnboarding
                #endif
                
                // Start initialization process
                Task {
                    await waitForInitialization()
                }
            }
        }
        .handlesExternalEvents(matching: [])
        #endif
    }
    
    // MARK: - Permission Handling
    
    /// Requests microphone permission using the PermissionManager.
    private func requestMicrophonePermission() {
        log("Checking microphone permission")
        PermissionManager.shared.checkMicrophonePermission { granted in
            if !granted {
                // Handle the case where microphone permission is denied
                // You might show an alert or update the UI accordingly
                print("Microphone permission was not granted.")
            } else {
                print("Microphone permission granted.")
            }
            log(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
        }
    }
    // Add this helper function
    private func clearKeychain(for bundleId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: bundleId
        ]
        SecItemDelete(query as CFDictionary)
    }
}
