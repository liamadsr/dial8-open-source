//
//  ProfileView.swift
//  dial8
//
//  Created by Liam Alizadeh
//

/// ProfileView and SettingsView are the main user profile management components of Dial8.
///
/// This file contains two main view structures:
/// 1. ProfileView: A compact menu-style view that appears in the app's toolbar, showing:
///    - User's initials in a circular avatar
///    - Dropdown menu for quick access to settings and logout
///
/// 2. SettingsView: A comprehensive settings panel that manages:
///    - Account information and subscription status
///    - Connected accounts (Calendar, Gmail, etc.)
///    - App preferences (language, launch behavior)
///    - Speech-to-text model settings
///    - Developer options (when in development mode)
///
/// The settings view is organized into logical sections, each handling different aspects
/// of the application's configuration. It uses custom components like SettingsRow,
/// ToggleRow, and ConnectedAccountRow for consistent UI presentation.
///
/// Dependencies:
///   - SwiftUI
///   - AppKit (macOS)
///   - Sparkle (for updates)
///   - ServiceManagement (for launch at login)
///
/// Usage:
/// ```swift
/// ProfileView(showSettings: $showSettingsBinding)
///     .environmentObject(authManager)
/// ```

import SwiftUI
#if os(macOS)
import AppKit
import Sparkle
import ServiceManagement
#endif

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.colorScheme) var colorScheme
    @State private var showingProfileMenu = false
    @Binding var showSettings: Bool
    
    #if os(macOS)
    // Computed property to access the AppDelegate
    private var appDelegate: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }
    #endif
    
    // Computed property to get user initials
    private var userInitials: String {
        guard let fullName = authManager.currentUser?.username else { return "?" }
        let components = fullName.split(separator: " ")
        if components.count >= 2 {
            let firstInitial = components[0].prefix(1)
            let lastInitial = components[components.count - 1].prefix(1)
            return "\(firstInitial)\(lastInitial)".uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                showingProfileMenu.toggle()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 28, height: 28)
                    
                    Text(userInitials)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yellow)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .background(showingProfileMenu ? Color.gray.opacity(0.3) : Color.clear)
            .cornerRadius(6)
        }
        .popover(isPresented: $showingProfileMenu, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                Button(action: {
                    showingProfileMenu = false
                    showSettings = true
                }) {
                    HStack {
                        Text("Settings")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                
                Button(action: {
                    showingProfileMenu = false  // Close the menu first
                    // Logout notification removed  // Post logout notification
                    authManager.signOut()  // Then sign out
                }) {
                    HStack {
                        Text("Log Out")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 200)
            .background(
                VisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow
                )
            )
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.colorScheme) var colorScheme
    @State private var correctSpelling = true
    @State private var openLinksInDesktop = true
    @State private var positionOnScreen = "Bottom Center"
    @State private var keyboardShortcut = "⌘Space"
    @State private var mainLanguage = "English"
    @State private var googleCalendarConnected = false
    @State private var gmailConnected = false
    @State private var instagramConnected = false
    @State private var redditConnected = false
    @AppStorage("showOnboardingInDevMode") private var showOnboardingInDevMode = false
    @AppStorage("devModeEnabled") private var devModeEnabled = false
    @AppStorage("isSmartCopyEnabled") private var isSmartCopyEnabled = true
    @AppStorage("simulateFirstLaunch") private var simulateFirstLaunch = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var manualWordCount: String = "0"
    @State private var selectedSubscriptionStatus = SubscriptionStatus.active
    
    // Initialize with optional initial tab
    init(initialTab: String? = nil) {
        // No longer need to set selected tab
    }

    #if os(macOS)
    // Computed property to access the AppDelegate
    private var appDelegate: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }
    #endif

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                VStack(spacing: 0) {
                    // Remove tab selector and replace with a header
                    HStack {
                        Text("Settings")
                            .font(.headline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .background(
                        ZStack {
                            VisualEffectView(
                                material: .hudWindow,
                                blendingMode: .behindWindow
                            )
                            Color(NSColor.windowBackgroundColor).opacity(0.7)
                        }
                    )
                    
                    Divider()
                    
                    // Scrollable Content with all sections
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Account Section
                            accountSection
                            
                            // App Section
                            appSection
                            
                            // About Section
                            aboutSection
                            
                            #if DEVELOPMENT
                            // Developer Section (only in development)
                            developerSection
                            #endif
                        }
                        .padding()
                    }
                }
                .frame(width: 550, height: 700)
                .background(Color(NSColor.windowBackgroundColor))
                .onAppear {
                    // Check authentication status when the view appears
                    if !authManager.isAuthenticated {
                        // Close the settings window if it's open
                        if let window = NSApp.windows.first(where: { $0.title == "Settings" }) {
                            window.close()
                        }
                    }
                    
                }
            } else {
                Text("Please log in to access settings.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account").font(.headline)
            GroupBox {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "envelope", 
                        title: "Email", 
                        value: authManager.currentUser?.email ?? "Not available"
                    )
                    Divider()
                    SettingsRow(
                        icon: "creditcard", 
                        title: "Subscription", 
                        value: "Dial8 \(authManager.accountStatus?.type.capitalized ?? "Basic")"
                    )
                }
            }
        }
    }
    
    var appSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App").font(.headline)
            GroupBox {
                VStack(spacing: 0) {
                    ToggleRow(icon: "arrow.right.circle", title: "Launch At Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            toggleLaunchAtLogin(newValue)
                        }
                }
            }
        }
    }
    
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About").font(.headline)
            GroupBox {
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "app.badge", 
                        title: "Dial8", 
                        value: appVersion
                    )
                }
            }
            
            if authManager.isAuthenticated {
                Button(action: {
                    // Logout notification removed
                    authManager.signOut()
                }) {
                    Text("Log out")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    #if DEVELOPMENT
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer Settings").font(.headline)
            GroupBox {
                ToggleRow(icon: "ladybug", title: "Dev Mode", isOn: $devModeEnabled)
                if devModeEnabled {
                    Divider()
                    HStack {
                        Image(systemName: "textformat.123")
                            .frame(width: 20)
                            .foregroundColor(.secondary)
                        Text("Manual Word Count")
                        Spacer()
                        TextField("Count", text: $manualWordCount)
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Set") {
                            if let count = Int(manualWordCount) {
                                UsageManager.shared.currentWeekUsage = count
                            }
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    
                    Divider()
                    ToggleRow(icon: "person.fill.viewfinder", title: "Show Onboarding", isOn: $showOnboardingInDevMode)
                    Divider()
                    ToggleRow(icon: "1.circle", 
                             title: "Simulate Fresh Install", 
                             isOn: $simulateFirstLaunch)
                        .onChange(of: simulateFirstLaunch) { newValue in
                            if newValue {
                                // Comprehensive reset of app state
                                let bundleId = Bundle.main.bundleIdentifier!
                                
                                // Reset UserDefaults
                                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                                UserDefaults.standard.synchronize()
                                
                                // Explicitly set fresh install flags
                                UserDefaults.standard.set(true, forKey: "simulateFirstLaunch")
                                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                                UserDefaults.standard.set(true, forKey: "showOnboardingInDevMode")
                                
                                // Reset authentication
                                authManager.signOut()
                                
                                // Clear any cached data or tokens
                                // You might want to add more specific clearing methods here
                                
                                // Notify user and restart
                                let alert = NSAlert()
                                alert.messageText = "Fresh Install Simulation"
                                alert.informativeText = "App will restart to simulate a fresh install."
                                alert.alertStyle = .informational
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                                
                                // Restart the app
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    exit(0)
                                }
                            }
                        }
                    
                    // Add new section for last sync threshold
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .frame(width: 20)
                            .foregroundColor(.secondary)
                        Text("Last Sync Threshold")
                        Spacer()
                        TextField("Threshold", text: .init(
                            get: { String(UserDefaults.standard.integer(forKey: "lastSyncThreshold")) },
                            set: { newValue in
                                if let threshold = Int(newValue) {
                                    UserDefaults.standard.set(threshold, forKey: "lastSyncThreshold")
                                }
                            }
                        ))
                        .frame(width: 80)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Reset") {
                            UserDefaults.standard.set(0, forKey: "lastSyncThreshold")
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    
                    HStack {
                        Image(systemName: "creditcard")
                            .frame(width: 20)
                            .foregroundColor(.secondary)
                        Text("Subscription Status")
                        Spacer()
                        Picker("Status", selection: $selectedSubscriptionStatus) {
                            ForEach(SubscriptionStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .frame(width: 120)
                        Button("Set") {
                            Task {
                                do {
                                    try await StripeService.shared.updateSubscriptionStatus(selectedSubscriptionStatus)
                                } catch {
                                    print("❌ Failed to update subscription status: \(error)")
                                    #if os(macOS)
                                    let alert = NSAlert()
                                    alert.messageText = "Failed to Update Status"
                                    alert.informativeText = "Could not update subscription status. Please try again."
                                    alert.alertStyle = .warning
                                    alert.addButton(withTitle: "OK")
                                    alert.runModal()
                                    #endif
                                }
                            }
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    
                    Divider()
                    
                    // Add the reset subscription button
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 20)
                            .foregroundColor(.secondary)
                        Text("Reset Subscription")
                        Spacer()
                        Button("Reset") {
                            // Show confirmation alert
                            let alert = NSAlert()
                            alert.messageText = "Reset Subscription"
                            alert.informativeText = "This will completely reset the subscription state for testing purposes. Are you sure?"
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "Reset")
                            alert.addButton(withTitle: "Cancel")
                            
                            let response = alert.runModal()
                            if response == .alertFirstButtonReturn {
                                Task {
                                    do {
                                        try await StripeService.shared.resetSubscription()
                                        // Show success alert
                                        let successAlert = NSAlert()
                                        successAlert.messageText = "Subscription Reset"
                                        successAlert.informativeText = "Subscription has been reset successfully. You can now test the subscription flow again."
                                        successAlert.alertStyle = .informational
                                        successAlert.addButton(withTitle: "OK")
                                        successAlert.runModal()
                                    } catch {
                                        // Show error alert
                                        let errorAlert = NSAlert()
                                        errorAlert.messageText = "Reset Failed"
                                        errorAlert.informativeText = "Failed to reset subscription: \(error.localizedDescription)"
                                        errorAlert.alertStyle = .critical
                                        errorAlert.addButton(withTitle: "OK")
                                        errorAlert.runModal()
                                    }
                                }
                            }
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
            }
            Text("Fresh Install Mode will completely reset the app state, simulating a new installation.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    #endif

    // Non-development version for compilation
    #if !DEVELOPMENT
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Developer options not available in production mode")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    #endif

    private func toggleLaunchAtLogin(_ isOn: Bool) {
        #if os(macOS)
        do {
            if isOn {
                try SMAppService.mainApp.register()
                print("Launch at Login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                print("Launch at Login disabled")
            }
        } catch {
            print("Failed to \(isOn ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            
            // Revert the toggle if setting fails
            DispatchQueue.main.async {
                launchAtLogin = !isOn
            }
            
            let alert = NSAlert()
            alert.messageText = "Unable to Change Launch Settings"
            alert.informativeText = "Could not modify launch at login preference. Please check your system settings."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        #endif
    }

    // Computed property to get the app version dynamically
    private var appVersion: String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

struct SettingsRow: View {
    var icon: String? = nil
    let title: String
    var value: String? = nil
    var hasDisclosure: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .frame(width: 20)
                        .foregroundColor(.secondary)
                }
                Text(title)
                Spacer()
                if let value = value {
                    Text(value)
                        .foregroundColor(.secondary)
                }
                if hasDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ToggleRow: View {
    var icon: String? = nil
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundColor(.secondary)
            }
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

struct ConnectedAccountRow: View {
    let icon: String
    let title: String
    @Binding var isConnected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            Text(title)
            Spacer()
            Button(action: {
                isConnected.toggle()
                // Here you would typically call a function to handle the connection/disconnection
            }) {
                Text(isConnected ? "Connected" : "Connect")
                    .frame(width: 75)
                    .padding(.vertical, 4)
                    .background(isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isConnected ? Color.green : Color.gray, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

// Add this helper function to estimate the size of the model
func getEstimatedSize(for modelId: String) -> String {
    switch modelId {
    case "Tiny":
        return "77.7 MB"
    case "Base":
        return "148 MB"
    case "Small":
        return "487.6 MB"
    case "Medium":
        return "1.53 GB"
    case "Large":
        return "3.09 GB"
    default:
        return "Unknown"
    }
}
