import SwiftUI

struct UnifiedSettingsView: View {
    @EnvironmentObject var audioManager: AudioManager
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var whisperManager = WhisperManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: SettingsSection = .recentActivity
    @State private var isSidebarVisible: Bool = true
    
    // Permission states
    @State private var hasPermissionIssues = false
    @State private var hasModelIssues = false
    
    enum SettingsSection: String, CaseIterable {
        case recentActivity = "Recent Activity"
        case modelSettings = "Model Settings"
        case hotkeys = "Hotkeys"
        case appSettings = "App Settings"
        case support = "Support & Feedback"
        #if DEVELOPMENT
        case developer = "Developer"
        #endif
        
        var icon: String {
            switch self {
            case .recentActivity: return "clock.arrow.circlepath"
            case .modelSettings: return "waveform.circle"
            case .hotkeys: return "keyboard"
            case .appSettings: return "gearshape"
            case .support: return "megaphone"
            #if DEVELOPMENT
            case .developer: return "hammer.fill"
            #endif
            }
        }
        
        var color: Color {
            switch self {
            case .recentActivity: return .indigo
            case .modelSettings: return .blue
            case .hotkeys: return .purple
            case .appSettings: return .green
            case .support: return .orange
            #if DEVELOPMENT
            case .developer: return .red
            #endif
            }
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(isSidebarVisible ? .doubleColumn : .detailOnly)) {
            // Sidebar
            VStack(spacing: 0) {
                // Add top padding for sidebar
                Color.clear
                    .frame(height: 20)
                
                List(selection: $selectedSection) {
                    ForEach(SettingsSection.allCases, id: \.self) { section in
                        HStack {
                            Label {
                                Text(section.rawValue)
                                    .font(.system(size: 14))
                            } icon: {
                                Image(systemName: section.icon)
                                    .font(.system(size: 16))
                            }
                            
                            Spacer()
                            
                            // Show warning indicator for sections with issues
                            if (section == .appSettings && hasPermissionIssues) ||
                               (section == .modelSettings && hasModelIssues) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                            }
                        }
                        .tag(section)
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200)
            .background(colorScheme == .dark ? Color.black.opacity(0.5) : Color.clear)
        } detail: {
            // Detail view
            VStack(spacing: 0) {
                // Top bar with sidebar toggle
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSidebarVisible.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                    
                    Spacer()
                }
                .frame(height: 40)
                .background(colorScheme == .dark ? Color.black.opacity(0.95) : Color(NSColor.windowBackgroundColor))
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        switch selectedSection {
                        case .recentActivity:
                            historySection
                        case .modelSettings:
                            modelSettingsSection
                        case .hotkeys:
                            hotkeysSection
                        case .appSettings:
                            appSettingsSection
                        case .support:
                            supportSection
                        #if DEVELOPMENT
                        case .developer:
                            developerSection
                        #endif
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                .background(colorScheme == .dark ? Color.black.opacity(0.95) : Color(NSColor.windowBackgroundColor))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colorScheme == .dark ? Color.black.opacity(0.95) : Color(NSColor.windowBackgroundColor))
        }
        .background(colorScheme == .dark ? Color.black : Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 800, idealWidth: 1000, maxWidth: .infinity)
        .onAppear {
            checkForIssues()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            checkForIssues()
        }
    }
    
    private func checkForIssues() {
        // Check permissions
        PermissionManager.shared.checkMicrophonePermission { micGranted in
            let accessibilityGranted = PermissionManager.shared.checkAccessibilityPermission()
            
            PermissionManager.shared.checkSpeechRecognitionPermission { speechGranted in
                DispatchQueue.main.async {
                    self.hasPermissionIssues = !(micGranted && accessibilityGranted && speechGranted)
                }
            }
        }
        
        // Check model status
        if let model = whisperManager.availableModels.first {
            hasModelIssues = !model.isAvailable && !whisperManager.isDownloading
        } else {
            hasModelIssues = true
        }
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header with Buy Me a Coffee button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Activity")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Click any transcription to copy to clipboard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Buy Me a Coffee button
                Button(action: {
                    if let url = URL(string: "https://buymeacoffee.com/liamadsr") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("☕️")
                            .font(.system(size: 16))
                        Text("Buy Me a Coffee")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.4, green: 0.6, blue: 1.0),  // Soft blue
                                Color(red: 0.8, green: 0.4, blue: 0.9),  // Purple-pink
                                Color(red: 1.0, green: 0.4, blue: 0.6)   // Pink-red
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            
            TranscriptionHistoryView()
        }
    }
    
    // MARK: - Model Settings Section
    private var modelSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("Model Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            WhisperModelSelectionView(
                showTitle: false,
                showDescription: true
            )
        }
    }
    
    // MARK: - Hotkeys Section
    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("Hotkeys")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Configure your keyboard shortcuts")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HotKeysView()
        }
    }
    
    // MARK: - App Settings Section
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("App Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Configure general application settings")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            AppSetupView()
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            Text("Support & Feedback")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            SupportView()
        }
    }
    
    #if DEVELOPMENT
    // MARK: - Developer Section
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section Header
            Text("Developer Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Debug options for development")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Onboarding Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Onboarding")
                    .font(.headline)
                
                HStack {
                    Text("Onboarding Status")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(UserDefaults.standard.hasCompletedOnboarding ? "Completed" : "Not Completed")
                        .foregroundColor(UserDefaults.standard.hasCompletedOnboarding ? .green : .orange)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Current Step")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(UserDefaults.standard.integer(forKey: "currentOnboardingStep"))")
                        .fontWeight(.medium)
                }
                
                Divider()
                
                Button(action: {
                    UserDefaults.standard.hasCompletedOnboarding = false
                    UserDefaults.standard.set(1, forKey: "currentOnboardingStep")
                    
                    // Restart the app
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-n", Bundle.main.bundlePath]
                    task.launch()
                    
                    // Terminate current instance
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: {
                    UserDefaults.standard.hasCompletedOnboarding = true
                }) {
                    Label("Mark Onboarding Complete", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    // Reset the hotkey test completion state
                    UserDefaults.standard.set(false, forKey: "fnKeySetupComplete")
                    UserDefaults.standard.synchronize()
                }) {
                    Label("Reset Hotkey Test", systemImage: "keyboard.badge.ellipsis")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
    }
    #endif
}

// Preview
struct UnifiedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedSettingsView()
            .environmentObject(AudioManager())
    }
}