/**
 * OnboardingView - A comprehensive onboarding experience for the Dial8 app
 *
 * This view manages the complete onboarding flow for new users, guiding them through:
 * 1. Authentication and sign-up
 * 2. Model selection and privacy settings
 * 3. Required permissions (microphone and accessibility)
 * 4. Function key (fn) setup and configuration
 * 5. Feature discovery and hands-free mode
 *
 * Key Features:
 * - Multi-step progressive onboarding with visual guidance
 * - Interactive demonstrations and animations
 * - Permission management (microphone, accessibility)
 * - System preferences integration
 * - State persistence across app restarts
 * - Development testing mode support
 *
 * State Management:
 * - Uses @AppStorage for persistent state
 * - Manages multiple permission states
 * - Handles system preference changes
 * - Coordinates with AuthenticationManager and WhisperManager
 *
 * Visual Components:
 * - Custom animations for feature demonstrations
 * - Interactive key visualizations
 * - Progress indicators
 * - Split-view layout with contextual help
 *
 * Integration Points:
 * - AuthenticationManager for user authentication
 * - WhisperManager for model selection/download
 * - AudioManager for recording functionality
 * - System preferences for permissions
 *
 * Usage:
 * The view is typically presented when:
 * - The app is launched for the first time
 * - Required permissions are missing
 * - Onboarding needs to be completed
 */

import SwiftUI
import AuthenticationServices
import AVFoundation
import ApplicationServices

struct OnboardingView: View {
    @StateObject var whisperManager = WhisperManager.shared
    @StateObject private var audioManager: AudioManager
    @Environment(\.colorScheme) private var colorScheme

    // Persist the currentStep using @AppStorage
    @AppStorage("currentOnboardingStep") private var currentStep = 1
    private let totalSteps = 4

    // MARK: - State Variables

    // Sign-in state
    @State private var userName = ""
    @State private var heardAboutUs = ""

    // Permissions state
    @State private var microphonePermissionGranted = false
    @State private var microphonePermissionManuallyGranted = false
    @State private var accessibilityPermissionGranted = false
    @State private var showAccessibilityPrompt = false {
        didSet {
            print("⌨️ ONBOARDING: showAccessibilityPrompt changed to: \(showAccessibilityPrompt)")
        }
    }
    @State private var navigatingToSettingsForAccessibility = false
    @State private var navigatingToSettingsForMicrophone = false
    @State private var showMicrophonePrompt = false

    // Model selection state
    @AppStorage("useLocalWhisperModel") private var useLocalWhisperModel = true
    @AppStorage("fnKeySetupComplete") private var fnKeySetupComplete = false

    // Existing Variables
    @State private var fnKeyDisabled = false
    @State private var isHovering = false

    // MARK: - Testing Mode
    /// Enables additional controls for testing the onboarding flow
    @State private var isTestingMode = true // Set to false to disable testing mode

    @State private var showingAlert = false
    @State private var alertMessage = ""

    // Computed property to get the appropriate notification name
    var didBecomeActiveNotification: Notification.Name {
        #if os(macOS)
        return NSApplication.didBecomeActiveNotification
        #else
        return UIApplication.didBecomeActiveNotification
        #endif
    }

    // Add these testing controls
    #if DEVELOPMENT
    @State private var showTestingControls = true

    private var testingControls: some View {
        VStack {
            HStack {
                Button(action: {
                    if currentStep > 1 {
                        currentStep -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(currentStep > 1 ? .blue : .gray)
                }
                .disabled(currentStep <= 1)

                Text("Step \(currentStep)")
                    .font(.caption)

                Button(action: {
                    if currentStep < totalSteps {
                        currentStep += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(currentStep < totalSteps ? .blue : .gray)
                }
                .disabled(currentStep >= totalSteps)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.3))
            .cornerRadius(8)

            Button("Reset Onboarding") {
                currentStep = 1
                UserDefaults.standard.hasCompletedOnboarding = false
            }
            .font(.caption)
            .padding(4)
            .background(Color.red.opacity(0.3))
            .cornerRadius(4)
        }
        .padding(8)
    }
    #endif

    // Add this property to the OnboardingView struct
    @AppStorage("needsPermissionCheckAfterRestart") private var needsPermissionCheckAfterRestart = false

    // Add new state variable
    @State private var fnKeyConfigured = false

    // Add new state variables at the top of OnboardingView
    @State private var showingFnKeySetup = false

    // Add this near the top with other @State variables
    @State private var demoMessage = ""

    // Add this state variable at the top with other @State variables
    @State private var hasShownAccessibilityPrompt = false

    // Add a new enum to track which alert should be shown
    enum ActiveAlert {
        case microphone
        case accessibility
        case error
    }

    // Update state variables
    @State private var activeAlert: ActiveAlert?
    @State private var showAlert = false

    // Add this helper computed property
    private var canGoBack: Bool {
        // If authenticated, can go back if current step > 2
        // If not authenticated, can go back if current step > 1
        return currentStep > 1
    }

    // Add this state variable at the top with other state variables
    @AppStorage("hasOpenedKeyboardSettings") private var hasOpenedKeyboardSettings = false

    // Add this at the top of OnboardingView struct with other @State variables
    @State private var fnKeyEventMonitor: Any?
    @State private var globalKeyEventMonitor: Any?

    // MARK: - Main View Body
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left side: Onboarding content
                VStack(spacing: 0) {
                    // Add back button at the top
                    if canGoBack {
                        HStack {
                            Button(action: {
                                currentStep -= 1
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }

                    // Download Progress View now inside the left VStack
                    DownloadProgressView()
                        .frame(height: whisperManager.isDownloading ? nil : 0)
                        .animation(.default, value: whisperManager.isDownloading)

                    // Display the appropriate step based on currentStep
                    if currentStep == 1 {
                        stepTwoModelSelection
                    } else if currentStep == 2 {
                        stepThreeMicrophonePermission
                    } else if currentStep == 3 {
                        stepFourAccessibilityPermission
                    } else if currentStep == 4 {
                        stepSixFnKeyVerification
                    }
                }
                .frame(width: geometry.size.width)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colorScheme == .dark ? Color.black.opacity(0.95) : Color(NSColor.windowBackgroundColor))
            .onAppear {
                if needsPermissionCheckAfterRestart {
                    checkPermissions()
                    needsPermissionCheckAfterRestart = false
                } else if !UserDefaults.standard.hasCompletedOnboarding {
                    // Resume onboarding at the saved step
                    checkPermissions()
                }
                // If onboarding is completed, do nothing
            }
            .onReceive(NotificationCenter.default.publisher(for: didBecomeActiveNotification)) { _ in
                print("⌨️ ONBOARDING: Received didBecomeActive notification")
                onAppDidBecomeActive()
            }
            .alert(isPresented: $showAlert) {
                switch activeAlert {
                case .microphone:
                    return Alert(
                        title: Text("Microphone Permission"),
                        message: Text("Did you grant microphone permission in System Preferences?"),
                        primaryButton: .default(Text("Yes")) {
                            self.microphonePermissionGranted = true
                        },
                        secondaryButton: .cancel(Text("No"))
                    )
                case .accessibility:
                    return Alert(
                        title: Text("Accessibility Permission"),
                        message: Text("Did you grant accessibility permission in System Preferences?"),
                        primaryButton: .default(Text("Yes")) {
                            print("⌨️ ONBOARDING: User clicked Yes on accessibility prompt")
                            let permissionGranted = PermissionManager.shared.checkAccessibilityPermission()
                            self.accessibilityPermissionGranted = permissionGranted
                            if permissionGranted {
                                print("⌨️ ONBOARDING: Accessibility permission verified")
                                self.checkPermissions()
                                self.restartApp()
                            } else {
                                print("⌨️ ONBOARDING: Accessibility permission not detected")
                                self.alertMessage = "Accessibility permission was not detected. Please try again."
                                self.activeAlert = .error
                                self.showAlert = true
                            }
                        },
                        secondaryButton: .cancel(Text("No"))
                    )
                case .error:
                    return Alert(
                        title: Text("Error"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Error"), message: Text("Unknown alert type"), dismissButton: .default(Text("OK")))
                }
            }
            // Add this onChange modifier to reset accessibility state when step changes
            .onChange(of: currentStep) { newStep in
                if newStep == 4 {
                    // Reset accessibility-related state when entering step 4
                    hasShownAccessibilityPrompt = false
                    navigatingToSettingsForAccessibility = false
                    showAccessibilityPrompt = false
                }
            }
        }
    }

    // MARK: - Step 1: Sign-In Screen
    /// Displays the initial sign-in options for users
    var stepOneSignIn: some View {
        SignInView()
    }

    // MARK: - Step 2: Model Selection and Data Privacy
    /// Allows users to select the Whisper model and informs them about local processing and data privacy
    var stepTwoModelSelection: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.headline)
                    .foregroundColor(.gray)

                Text("Welcome to Dial8")
                    .font(.system(size: 48, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text("Download Speech-to-Text Model")
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)

                Text("All audio processing is done locally on your device. Your data is never sent to any servers or used for training.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Model information - simplified to show only Medium model
                VStack(alignment: .leading, spacing: 20) {
                    // Show information about the Medium model
                    if let mediumModel = whisperManager.availableModels.first {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                
                                Text("Multilingual Mode")
                                    .font(.headline)
                            }
                            
                            Text(mediumModel.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            // Show download button if not already downloaded
                            if !mediumModel.isAvailable && !whisperManager.isDownloading {
                                Button(action: {
                                    whisperManager.downloadModel(modelSize: "Medium")
                                }) {
                                    Label("Download Model", systemImage: "arrow.down.circle")
                                }
                                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                                .padding(.top, 8)
                            } else if mediumModel.isAvailable {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Model Ready")
                                        .foregroundColor(.green)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        Text("Loading model information...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                // Updated continue button with disabled state message
                VStack(spacing: 8) {
                    Button("Continue") {
                        currentStep = 2
                    }
                    .buttonStyle(.borderedProminent)
                .controlSize(.large)
                    .disabled(!isModelSelectedAndReady())

                    if !isModelSelectedAndReady() {
                        Text("Please download the model to continue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
            }
            .padding(.vertical, 40)
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Step 3: Microphone Permission
    var stepThreeMicrophonePermission: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Step \(currentStep) of \(totalSteps)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Microphone Access")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                }
                .padding(.top, 40)
                
                // Icon and explanation
                VStack(spacing: 24) {
                    // Microphone icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 8)
                    
                    // Main explanation
                    Text("Enable speech-to-text transcription")
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text("Dial8 needs microphone access to convert your voice into text. Your audio is processed entirely on your device and never leaves your computer.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    
                    // Added Key benefits
                    VStack(spacing: 16) {
                        PermissionBenefitRow(icon: "mic.fill", text: "Voice-to-Text Transcription")
                        PermissionBenefitRow(icon: "xmark.bin.fill", text: "Recordings Never Saved")
                        PermissionBenefitRow(icon: "laptopcomputer", text: "Processed Locally on Your Mac")
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                    .frame(height: 20)
                
                // Permission button area
                VStack(spacing: 16) {
                    if microphonePermissionGranted {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Microphone Access Granted")
                                .font(.headline)
                        }
                        .padding(.bottom, 8)
                        
                        Button("Continue") {
                            currentStep = 3
                        }
                        .buttonStyle(.borderedProminent)
                .controlSize(.large)
                    } else {
                        Button(action: requestMicrophonePermission) {
                            HStack(spacing: 8) {
                                Image(systemName: "mic.fill")
                                Text("Enable Microphone Access")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                .controlSize(.large)
                        
                        Text("Required for voice transcription")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, minHeight: 600)
        }
    }

    // Add this helper view for the benefit rows
    private struct PermissionBenefitRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack {
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    if text.contains("Press") {
                        HStack(spacing: 4) {
                            Text("Find 'Press")
                            Image(systemName: "globe")
                                .font(.body)
                            Text("key to'")
                        }
                        .font(.body)
                        .foregroundColor(.primary)
                    } else {
                        Text(text)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Step 4: Accessibility Permission
    var stepFourAccessibilityPermission: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Step \(currentStep) of \(totalSteps)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Accessibility Access")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                }
                .padding(.top, 40)
                
                // Icon and explanation
                VStack(spacing: 24) {
                    // Updated icon to better represent text insertion
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "text.cursor")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 8)
                    
                    // Updated main explanation
                    Text("Enable Text Insertion")
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text("Dial8 needs accessibility access to insert transcribed text into any app on your Mac. This allows you to transcribe directly into your favorite apps.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    
                    // Key benefits
                    VStack(spacing: 16) {
                        PermissionBenefitRow(icon: "apps.iphone", text: "Works in Any App")
                        PermissionBenefitRow(icon: "text.cursor", text: "Insert Text Anywhere")
                        PermissionBenefitRow(icon: "keyboard", text: "Hotkey Detection")
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                    .frame(height: 20)
                
                // Permission button area
                VStack(spacing: 16) {
                    if accessibilityPermissionGranted {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Accessibility Access Granted")
                                .font(.headline)
                        }
                        .padding(.bottom, 8)
                        
                        Button("Continue") {
                            currentStep = 4
                        }
                        .buttonStyle(.borderedProminent)
                .controlSize(.large)
                    } else {
                        Button(action: requestAccessibilityPermission) {
                            HStack(spacing: 8) {
                                Image(systemName: "text.cursor")
                                Text("Enable Accessibility Access")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                .controlSize(.large)
                        
                        Text("Required for text insertion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, minHeight: 600)
        }
    }


    // MARK: - Step 6: Hotkey Verification
    var stepSixFnKeyVerification: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Hotkey Test")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
            }
            .padding(.top, 40)
            
            // Icon and verification area
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    if fnKeySetupComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 90, weight: .medium))
                            .foregroundColor(.green)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.1)
                                        .combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                            .rotationEffect(.degrees(fnKeySetupComplete ? 360 : 0))
                    } else {
                        Image(systemName: "keyboard")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                }
                .animation(
                    fnKeySetupComplete ? 
                        .spring(response: 0.6, dampingFraction: 0.7)
                        .delay(0.1) : 
                        .easeOut(duration: 0.3),
                    value: fnKeySetupComplete
                )
                
                if fnKeySetupComplete {
                    VStack(spacing: 12) {
                        Text("Everything's Ready!")
                            .font(.title2)
                            .fontWeight(.medium)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                        Text("Your setup is complete")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.easeOut(duration: 0.3).delay(0.2), value: fnKeySetupComplete)
                } else {
                    VStack(spacing: 12) {
                        Text("Let's Test Your Setup")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 4) {
                            Text("Hold down the")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "option")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Option")
                                    .font(.system(size: 20, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            
                            Text("key")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Button area
            if fnKeySetupComplete {
                Button("Get Started") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .padding(.bottom, 40)
            }
        }
        .animation(.easeOut(duration: 0.3), value: fnKeySetupComplete)
        .onAppear {
            print("⌨️ STEP 6: View appeared, setting up notification observer")
            
            // Start general hotkey detection
            DispatchQueue.main.async {
                print("⌨️ STEP 6: Starting hotkey detection")
            }
            
            // Create notification observer for hotkey press
            NotificationCenter.default.addObserver(
                forName: .fnKeySetupComplete,
                object: nil,
                queue: .main
            ) { notification in
                print("⌨️ STEP 6: Received hotkey notification: \(notification)")
                withAnimation {
                    print("⌨️ STEP 6: Setting fnKeySetupComplete to true")
                    self.fnKeySetupComplete = true
                    print("⌨️ STEP 6: fnKeySetupComplete is now \(self.fnKeySetupComplete)")
                }
            }
            
            // Setup hotkey detection for testing
            setupHotkeyDetection(persistOnFirstDetection: false)
            
            // Ensure this view has focus to detect key presses
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                print("⌨️ ONBOARDING: Activated app for hotkey detection")
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(
                self,
                name: .fnKeySetupComplete,
                object: nil
            )
            
            // Remove the event monitors if they still exist
            if let monitor = fnKeyEventMonitor {
                print("⌨️ STEP 6: Cleaning up local event monitor on view disappear")
                NSEvent.removeMonitor(monitor)
                fnKeyEventMonitor = nil
            }
            if let globalMonitor = globalKeyEventMonitor {
                print("⌨️ STEP 6: Cleaning up global event monitor on view disappear")
                NSEvent.removeMonitor(globalMonitor)
                globalKeyEventMonitor = nil
            }
        }
    }

    // Update the setupHotkeyDetection method with an additional parameter
    private func setupHotkeyDetection(persistOnFirstDetection: Bool = false) {
        print("⌨️ ONBOARDING: Setting up hotkey detection for verification")
        print("⌨️ Current hotkey setup state: \(fnKeySetupComplete)")
        print("⌨️ Current onboarding step: \(currentStep)")
        
        // Check if we already have an active monitor
        if fnKeyEventMonitor != nil {
            print("⌨️ ONBOARDING: Event monitor already exists, removing it first")
            NSEvent.removeMonitor(fnKeyEventMonitor!)
            fnKeyEventMonitor = nil
        }
        
        // Create an event monitor to detect modifier key press during verification
        let eventMask = NSEvent.EventTypeMask.flagsChanged
        print("⌨️ ONBOARDING: Creating event monitor with mask \(eventMask)")
        
        // Use both local and global monitors for better detection
        fnKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { event in
            self.handleModifierKeyEvent(event, persistOnFirstDetection: persistOnFirstDetection)
            return event // Must return the event for local monitors
        }
        
        // Also add a global monitor as backup
        globalKeyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { event in
            self.handleModifierKeyEvent(event, persistOnFirstDetection: persistOnFirstDetection)
        }
        
        print("⌨️ ONBOARDING: Fn key event monitor setup complete: \(String(describing: fnKeyEventMonitor))")
    }
    
    private func handleModifierKeyEvent(_ event: NSEvent, persistOnFirstDetection: Bool) {
        // Skip if already complete
        if fnKeySetupComplete { return }
        
        let flagsRaw = UInt64(event.modifierFlags.rawValue)
        
        // Check specifically for Option key
        let isOptionPressed = event.modifierFlags.contains(.option)
        
        print("⌨️ ONBOARDING: Detected flag change - Option pressed: \(isOptionPressed), Raw flags: \(flagsRaw)")
        
        if isOptionPressed {
            print("⌨️ ONBOARDING: Option key detected!")
            
            // Post the notification to trigger the animation
            DispatchQueue.main.async {
                print("⌨️ ONBOARDING: Posting hotkey complete notification")
                NotificationCenter.default.post(name: .fnKeySetupComplete, object: nil)
                
                // Persist the state
                print("⌨️ ONBOARDING: Setting UserDefaults for fnKeySetupComplete")
                UserDefaults.standard.set(true, forKey: "fnKeySetupComplete")
                
                // Remove the monitors after first detection only if not persistent
                if !persistOnFirstDetection {
                    if let monitor = self.fnKeyEventMonitor {
                        print("⌨️ ONBOARDING: Removing local event monitor after detection")
                        NSEvent.removeMonitor(monitor)
                        self.fnKeyEventMonitor = nil
                    }
                    if let globalMonitor = self.globalKeyEventMonitor {
                        print("⌨️ ONBOARDING: Removing global event monitor after detection")
                        NSEvent.removeMonitor(globalMonitor)
                        self.globalKeyEventMonitor = nil
                    }
                }
            }
        }
    }

    // MARK: - Step 7: Discover Features
    var stepSevenDiscoverFeatures: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Push-to-Talk")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
            }
            .padding(.top, 40)
            
            // Visual Demo
            ZStack {
                // Background with adaptive coloring
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.primary.opacity(0.05))
                    .shadow(
                        color: Color.primary.opacity(0.1),
                        radius: 20,
                        x: 0,
                        y: 0
                    )
                
                KeyVisualView()
                    .frame(width: 240, height: 240)
                    .padding(40)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            
            Text("Perfect for quick thoughts and messages")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.top, 20)
            
            Spacer()
            
            Button("Continue") {
                currentStep = 8
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 8: Hands-Free Mode
    var stepEightHandsFreeMode: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Hands-Free Mode")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
            }
            .padding(.top, 40)
            
            // Visual Demo
            ZStack {
                // Background with adaptive coloring
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.primary.opacity(0.05))
                    .shadow(
                        color: Color.primary.opacity(0.1),
                        radius: 20,
                        x: 0,
                        y: 0
                    )
                
                HandsFreeKeyVisualView()
                    .frame(width: 240, height: 240)
                    .padding(40)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            
            Text("Perfect for longer recordings")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.top, 20)
            
            Spacer()
            
            Button("Get Started") {
                completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
    }

    struct HandsFreeKeyVisualView: View {
        @Environment(\.colorScheme) var colorScheme
        @State private var isPressed = false
        @State private var currentStep = 0
        @State private var showStepText = false
        @State private var textOpacity = 0.0
        @State private var textOffset: CGFloat = 100
        @State private var glowOpacity = 0.0
        
        let steps = [
            "Tap to Start",
            "Recording Locked",
            "Tap to Stop"
        ]
        
        var body: some View {
            ZStack(alignment: .center) {
                // Single glow effect layer that's larger than the button
                if currentStep == 1 {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red)
                        .blur(radius: 20)
                        .opacity(glowOpacity)
                        .frame(width: 300, height: 300) // Much larger to ensure full glow visibility
                }
                
                // Key visualization
                ZStack {
                    // Key shadow
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.4 : 0.3))
                        .offset(y: isPressed ? 1 : 8)
                        .blur(radius: 6)
                    
                    // Key body
                    ZStack {
                        // Background layer
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.primary.opacity(0.1))
                            .offset(y: isPressed ? 0 : -2)
                        
                        // Main key surface
                        RoundedRectangle(cornerRadius: 14)
                            .fill(colorScheme == .dark ? Color(white: 0.2) : .white)
                            .shadow(
                                color: Color.primary.opacity(isPressed ? 0.1 : 0.2),
                                radius: isPressed ? 2 : 6,
                                x: 0,
                                y: isPressed ? 1 : 4
                            )
                            .offset(y: isPressed ? 4 : 0)
                        
                        // Main content layout
                        ZStack {
                            // FN text in top right
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("fn")
                                        .font(.system(size: 60, weight: .regular))
                                        .foregroundColor(isPressed ? .blue : .secondary)
                                        .padding(.top, 12)
                                        .padding(.trailing, 16)
                                        .shadow(
                                            color: Color.primary.opacity(isPressed ? 0 : 0.1),
                                            radius: 1
                                        )
                                }
                                Spacer()
                            }
                            
                            // Globe icon in bottom left
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.system(size: 54))
                                        .foregroundColor(isPressed ? .blue : .secondary)
                                        .padding(.bottom, 12)
                                        .padding(.leading, 16)
                                        .shadow(
                                            color: Color.primary.opacity(isPressed ? 0 : 0.1),
                                            radius: 1
                                        )
                                    Spacer()
                                }
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                currentStep == 1 ? Color.red.opacity(0.3) : Color.primary.opacity(isPressed ? 0.3 : 0.1),
                                lineWidth: isPressed ? 2 : 1
                            )
                            .shadow(
                                color: Color.primary.opacity(isPressed ? 0.15 : 0),
                                radius: 3,
                                x: 0,
                                y: isPressed ? 2 : 0
                            )
                    )
                }
                .frame(width: 240, height: 240)
                
                // Step text
                if showStepText {
                    VStack {
                        Spacer()
                            .frame(height: 300)
                        stepText
                            .opacity(textOpacity)
                            .offset(x: textOffset)
                    }
                }
            }
            .frame(width: 340, height: 340) // Larger frame to accommodate glow
            .onAppear {
                startHandsFreeAnimation()
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: isPressed)
        }
        
        private var stepText: some View {
            VStack(spacing: 2) {
                switch steps[currentStep] {
                case "Tap to Start":
                    Text("Tap to Start")
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                case "Recording Locked":
                    Text("Recording Locked")
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                case "Tap to Stop":
                    Text("Tap to Stop")
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                default:
                    EmptyView()
                }
            }
        }
        
        private func startHandsFreeAnimation() {
            // Initial setup
            textOffset = 100
            textOpacity = 0
            currentStep = 0
            showStepText = true
            glowOpacity = 0
            
            // Quick tap to start
            withAnimation(.easeInOut(duration: 0.2)) {
                isPressed = true
            }
            
            // Show "Tap to Start"
            withAnimation(.easeOut(duration: 0.4)) {
                textOpacity = 1.0
                textOffset = 0
            }
            
            // Release tap
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPressed = false
                }
                
                // Transition to "Recording Locked" with glow
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeIn(duration: 0.4)) {
                        textOffset = -100
                        textOpacity = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        textOffset = 100
                        currentStep = 1
                        
                        // Show Recording Locked and glow immediately together
                        withAnimation(.easeOut(duration: 0.4)) {
                            textOffset = 0
                            textOpacity = 1.0
                            glowOpacity = 0.3
                        }
                        
                        // Start the pulsing glow animation
                        withAnimation(
                            Animation
                                .easeInOut(duration: 2)
                                .repeatForever(autoreverses: true)
                                .delay(0.4)
                        ) {
                            glowOpacity = 0.5
                        }
                        
                        // Show final "Tap to Stop" after shorter delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeIn(duration: 0.4)) {
                                textOffset = -100
                                textOpacity = 0
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                textOffset = 100
                                currentStep = 2  // Switch to "Tap to Stop"
                                
                                // Stop the glow
                                withAnimation {
                                    glowOpacity = 0
                                }
                                
                                // Quick tap to stop
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPressed = true
                                }
                                
                                withAnimation(.easeOut(duration: 0.4)) {
                                    textOffset = 0
                                    textOpacity = 1.0
                                }
                                
                                // Release final tap
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation {
                                        isPressed = false
                                    }
                                    
                                    // Fade out final text
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        withAnimation(.easeIn(duration: 0.4)) {
                                            textOffset = -100
                                            textOpacity = 0
                                        }
                                        
                                        // Reset and restart
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                            showStepText = false
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                startHandsFreeAnimation()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Supporting Views
    struct KeyVisualView: View {
        @Environment(\.colorScheme) var colorScheme
        @State private var isPressed = false
        @State private var currentStep = 0
        @State private var showStepText = false
        @State private var textOpacity = 0.0
        @State private var textOffset: CGFloat = 100 // For sliding animation
        
        let steps = [
            "Press & Hold",
            "Talk",
            "Release"
        ]
        
        var body: some View {
            ZStack(alignment: .center) {
                // Key visualization in fixed position
                ZStack {
                    // Enhanced key shadow - adaptive for dark mode
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.4 : 0.3))
                        .offset(y: isPressed ? 1 : 8)
                        .blur(radius: 6)
                    
                    // Key body
                    ZStack {
                        // Background layer for depth
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.primary.opacity(0.1))
                            .offset(y: isPressed ? 0 : -2)
                        
                        // Main key surface - adaptive background
                        RoundedRectangle(cornerRadius: 14)
                            .fill(colorScheme == .dark ? Color(white: 0.2) : .white)
                            .shadow(
                                color: Color.primary.opacity(isPressed ? 0.1 : 0.2),
                                radius: isPressed ? 2 : 6,
                                x: 0,
                                y: isPressed ? 1 : 4
                            )
                            .offset(y: isPressed ? 4 : 0)
                        
                        // Main content layout
                        ZStack {
                            // FN text in top right
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("fn")
                                        .font(.system(size: 60, weight: .regular))
                                        .foregroundColor(isPressed ? .blue : .secondary)
                                        .padding(.top, 12)
                                        .padding(.trailing, 16)
                                        .shadow(
                                            color: Color.primary.opacity(isPressed ? 0 : 0.1),
                                            radius: 1
                                        )
                                }
                                Spacer()
                            }
                            
                            // Globe icon in bottom left
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.system(size: 54))
                                        .foregroundColor(isPressed ? .blue : .secondary)
                                        .padding(.bottom, 12)
                                        .padding(.leading, 16)
                                        .shadow(
                                            color: Color.primary.opacity(isPressed ? 0 : 0.1),
                                            radius: 1
                                        )
                                    Spacer()
                                }
                            }
                        }
                    }
                    // Enhanced inner shadow - adaptive for dark mode
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                Color.primary.opacity(isPressed ? 0.3 : 0.1),
                                lineWidth: isPressed ? 2 : 1
                            )
                            .shadow(
                                color: Color.primary.opacity(isPressed ? 0.15 : 0),
                                radius: 3,
                                x: 0,
                                y: isPressed ? 2 : 0
                            )
                    )
                }
                .frame(width: 240, height: 240)
                
                // Step text in overlay
                if showStepText {
                    VStack {
                        Spacer()
                            .frame(height: 300)
                        stepText
                            .opacity(textOpacity)
                            .offset(x: textOffset)
                    }
                }
            }
            .frame(width: 240, height: 340)
            .onAppear {
                startKeyAnimation()
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: isPressed)
        }
        
        private var stepText: some View {
            VStack(spacing: 2) {
                switch steps[currentStep] {
                case "Press & Hold":
                    Text("Press & Hold")
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                case "Talk":
                    Text("Talk")
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                case "Release":
                    Text("Release")
                        .font(.system(size: 22, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                default:
                    EmptyView()
                }
            }
        }
        
        private func startKeyAnimation() {
            // First, position the text offscreen and make it invisible
            textOffset = 100  // Start from right
            textOpacity = 0
            currentStep = 0  // Start with "Press & Hold"
            showStepText = true
            
            // Press down animation
            withAnimation(.easeInOut(duration: 0.3)) {
                isPressed = true
            }
            
            // Slide in "Press & Hold" text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.4)) {
                    textOpacity = 1.0
                    textOffset = 0
                }
                
                // Transition to "Talk"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    // Slide out "Press & Hold"
                    withAnimation(.easeIn(duration: 0.4)) {
                        textOffset = -100
                        textOpacity = 0
                    }
                    
                    // Slide in "Talk"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        textOffset = 100
                        currentStep = 1  // Show "Talk"
                        withAnimation(.easeOut(duration: 0.4)) {
                            textOffset = 0
                            textOpacity = 1.0
                        }
                        
                        // Transition to "Release"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            // Slide out "Talk"
                            withAnimation(.easeIn(duration: 0.4)) {
                                textOffset = -100
                                textOpacity = 0
                            }
                            
                            // Slide in "Release" and release key
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                textOffset = 100
                                currentStep = 2  // Show "Release"
                                withAnimation(.easeOut(duration: 0.4)) {
                                    textOffset = 0
                                    textOpacity = 1.0
                                }
                                
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isPressed = false
                                }
                                
                                // Fade out final text
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.easeIn(duration: 0.4)) {
                                        textOffset = -100
                                        textOpacity = 0
                                    }
                                    
                                    // Reset and prepare for next cycle
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                        showStepText = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            startKeyAnimation()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    /// Checks if a model is selected and downloading/downloaded
    func isModelSelectedAndReady() -> Bool {
        // Check if the Medium model is downloaded and available or currently downloading
        return whisperManager.availableModels.first?.isAvailable ?? false || whisperManager.isDownloading
    }

    /// Checks the current permission statuses
    func checkPermissions() {
        print("⌨️ ONBOARDING: Checking permissions")
        // Check microphone permission synchronously
        PermissionManager.shared.checkMicrophonePermission { granted in
            self.microphonePermissionGranted = granted
        }

        // Check accessibility permission
        self.accessibilityPermissionGranted = PermissionManager.shared.checkAccessibilityPermission()
    }

    /// Requests microphone permission
    func requestMicrophonePermission() {
        PermissionManager.shared.requestMicrophonePermission { granted in
            DispatchQueue.main.async {
                self.microphonePermissionGranted = granted
                self.microphonePermissionManuallyGranted = granted
                if granted {
                    // Permission granted
                    self.checkPermissions()
                } else {
                    // Permission denied, navigate to System Preferences
                    self.navigatingToSettingsForMicrophone = true
                }
            }
        }
    }

    /// Requests accessibility permission
    func requestAccessibilityPermission() {
        print("⌨️ ONBOARDING: Requesting accessibility permission")
        if !accessibilityPermissionGranted {
            // Explicitly reset these states when requesting permission
            hasShownAccessibilityPrompt = false
            navigatingToSettingsForAccessibility = true
            showAccessibilityPrompt = false
            
            PermissionManager.shared.requestAccessibilityPermissionWithPrompt { granted in
                DispatchQueue.main.async {
                    self.accessibilityPermissionGranted = granted
                    if !granted {
                        self.openSystemPreferencesPrivacyAccessibility()
                    }
                }
            }
        }
    }

    /// Opens System Preferences to the Accessibility privacy settings
    func openSystemPreferencesPrivacyAccessibility() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    /// Handles app becoming active
    func onAppDidBecomeActive() {
        print("⌨️ ONBOARDING: App became active")
        print("⌨️ ONBOARDING: navigatingToSettingsForMicrophone: \(navigatingToSettingsForMicrophone)")
        print("⌨️ ONBOARDING: navigatingToSettingsForAccessibility: \(navigatingToSettingsForAccessibility)")
        print("⌨️ ONBOARDING: hasShownAccessibilityPrompt: \(hasShownAccessibilityPrompt)")
        
        if navigatingToSettingsForMicrophone {
            activeAlert = .microphone
            showAlert = true
            navigatingToSettingsForMicrophone = false
        }
        
        if navigatingToSettingsForAccessibility && !hasShownAccessibilityPrompt {
            self.activeAlert = .accessibility
            self.showAlert = true
            self.hasShownAccessibilityPrompt = true
            print("⌨️ ONBOARDING: Set accessibility alert to show")
        }
    }

    /// Marks onboarding as complete and prepares for app usage
    func completeOnboarding() {
        // Authentication completion removed
        UserDefaults.standard.hasCompletedOnboarding = true
        print("Onboarding completed")
        // Restart the app to ensure clean state
        restartApp()
    }

    /// Restarts the app
    func restartApp() {
        #if os(macOS)
        // Set the flag before restarting
        needsPermissionCheckAfterRestart = true
        
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", Bundle.main.bundlePath]
        task.launch()
        NSApplication.shared.terminate(nil)
        #endif
    }

    /// Generates an attributed string for terms and conditions
    private var termsAndConditionsAttributedString: AttributedString {
        var attributedString = AttributedString("By signing up you agree to our terms and conditions")

        // Set default style
        attributedString.font = .caption
        attributedString.foregroundColor = .gray

        // Style the "terms and conditions" part differently
        if let range = attributedString.range(of: "terms and conditions") {
            attributedString[range].font = .caption.bold()
            attributedString[range].foregroundColor = isHovering ? .blue : Color.primary
            attributedString[range].underlineStyle = isHovering ? .single : .none
        }

        return attributedString
    }


    // Add helper function to open keyboard settings
    func openKeyboardSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    // Add an initializer to OnboardingView
    init() {
        let audioManager = AudioManager()
        _audioManager = StateObject(wrappedValue: audioManager)
    }
}

// MARK: - Supporting Views

/// A row representing a permission with action to grant it
struct PermissionRow: View {
    var title: String
    var isGranted: Bool
    var action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isGranted ? .green : .gray)
            Text(title)
            Spacer()
            if !isGranted {
                Button("Allow") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

/// A row representing a feature highlight
struct FeatureRow: View {
    var icon: String
    var title: String
    var description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    /// Custom notification for when authentication is completed
    static let authenticationCompleted = Notification.Name("authenticationCompleted")
    static let fnKeySetupComplete = Notification.Name("fnKeySetupComplete")
    static let startFnKeyDetection = Notification.Name("startFnKeyDetection")
}

// MARK: - DownloadProgressView

struct DownloadProgressView: View {
    @ObservedObject var whisperManager = WhisperManager.shared

    var body: some View {
        if whisperManager.isDownloading {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.yellow, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * CGFloat(whisperManager.downloadProgress))
                }
            }
            .frame(height: 4)
            .padding(.horizontal)
        }
    }
}

// Add this new view for the floating arrow animation
struct FloatingArrowView: View {
    @State private var offsetY: CGFloat = 0
    
    var body: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.blue)
            .opacity(0.8)
            .offset(y: offsetY)
            .onAppear {
                withAnimation(
                    Animation
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                ) {
                    offsetY = 10
                }
            }
    }
}

// Update the StepInstructionView
struct StepInstructionView: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {  // Simplified HStack structure
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            Spacer()  // Push content to the left
        }
        .frame(maxWidth: 400)  // Consistent width with container
    }
}

// First, define the StepAnimation enum at the top level of the file
enum StepAnimation {
    case press, speak, release
    
    var initialDelay: Double {
        switch self {
        case .press: return 0.0    // Starts immediately
        case .speak: return 0.8    // Starts after press is held
        case .release: return 2.5   // Starts after speaking
        }
    }
    
    var duration: Double {
        switch self {
        case .press: return 0.3     // Quick press down
        case .speak: return 1.5     // Longer duration for speaking
        case .release: return 0.3   // Quick release
        }
    }
}

