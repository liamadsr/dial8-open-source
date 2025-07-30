import Foundation
import SwiftUI
@preconcurrency import WebKit
import Security
import os
import AuthenticationServices

// Define PresentationAnchor type based on the operating system
#if os(macOS)
import AppKit
public typealias PresentationAnchor = NSWindow
#else
import UIKit
public typealias PresentationAnchor = UIWindow
#endif

/// Manages user authentication and profile information
@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    // Singleton instance for global access
    static let shared = AuthenticationManager()

    // Logger for debugging and error tracking
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.dial8", category: "AuthenticationManager")

    // Published properties for reactive UI updates
    @Published var currentUser: UserProfile? {
        didSet {
            if let user = currentUser {
                saveUserProfile(user)
            }
        }
    }
    @Published var isAuthenticated = false
    @Published var accountStatus: AccountStatus? {
        didSet {
            if let status = accountStatus {
                saveAccountStatus(status)
                NotificationCenter.default.post(
                    name: NSNotification.Name("AccountStatusUpdated"),
                    object: nil
                )
            }
        }
    }

    // Private properties for managing the authentication process
    private var webView: WKWebView?
    private var presentationAnchor: PresentationAnchor?
    private var authWindow: NSWindow?

    // Add this new property

    // Add this new property
    @AppStorage("isFirstTimeUser") var isFirstTimeUser = true

    // MARK: - Sign In Methods

    /// Initiates the Google Sign-In process
    /// - Parameter presentationAnchor: The window or view controller to present the sign-in interface
    func signInWithGoogle(presentationAnchor: PresentationAnchor) {
        logger.info("Starting Google Sign-In process")
        self.presentationAnchor = presentationAnchor

        // Construct the Google OAuth URL
        // Note: In a production app, these values should be stored securely
        let redirectURI = "com.dial8.oauth:/oauthredirect"

        // Use the login endpoint from your backend
        let authURLString = "\(AppConfig.BACKEND_API_URL)/api/v1/auth/google?redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

        guard let authURL = URL(string: authURLString) else {
            logger.error("Invalid authentication URL: \(authURLString)")
            return
        }

        logger.info("Initiating ASWebAuthenticationSession with auth URL: \(authURL)")

        let scheme = "com.dial8.oauth"

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
            if let error = error {
                // Handle error
                self.logger.error("Authentication error: \(error.localizedDescription)")
                return
            }

            guard let callbackURL = callbackURL else {
                self.logger.error("No callback URL received from authentication session")
                return
            }

            self.handleAuthRedirect(url: callbackURL)
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true // Optional: doesn't share cookies with Safari
        session.start()
    }

    /// Handles the redirect after successful authentication
    /// - Parameter url: The URL containing authentication data
    public func handleAuthRedirect(url: URL) {
        print("🔐 AUTH: handleAuthRedirect called")
        logger.info("Handling auth redirect: \(url)")
        print("🔗 Redirect URL: \(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let accessToken = components.queryItems?.first(where: { $0.name == "access_token" })?.value,
              let refreshToken = components.queryItems?.first(where: { $0.name == "refresh_token" })?.value,
              let expiresInString = components.queryItems?.first(where: { $0.name == "expires_in" })?.value,
              let refreshExpiresInString = components.queryItems?.first(where: { $0.name == "refresh_token_expires_in" })?.value,
              let userIdString = components.queryItems?.first(where: { $0.name == "user_id" })?.value,
              let accountStatusString = components.queryItems?.first(where: { $0.name == "account_status" })?.value,
              let expiresIn = TimeInterval(expiresInString),
              let refreshExpiresIn = TimeInterval(refreshExpiresInString) else {
            logger.error("Invalid redirect URL or missing required parameters")
            return
        }

        // Decode account status - fixed version
        if let decodedAccountStatusString = accountStatusString
            .removingPercentEncoding?
            .replacingOccurrences(of: "+", with: " ") {
            
            print("📊 Decoded account status string: \(decodedAccountStatusString)")
            
            if let accountStatusData = decodedAccountStatusString.data(using: .utf8) {
                do {
                    let accountStatus = try JSONDecoder().decode(AccountStatus.self, from: accountStatusData)
                    Task { @MainActor in
                        self.accountStatus = accountStatus
                        print("✅ Successfully decoded account status: \(accountStatus)")
                    }
                } catch {
                    print("❌ Failed to decode account status: \(error)")
                    if let jsonString = String(data: accountStatusData, encoding: .utf8) {
                        print("📝 Raw JSON string: \(jsonString)")
                    }
                }
            }
        }

        Task { @MainActor in
            do {
                try AuthUtils.saveToKeychain(key: "userId", data: userIdString)
                print("✅ Successfully saved user ID to keychain")
                
                // Save both tokens with their respective expiration times
                TokenManager.shared.setTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiresIn: expiresIn,
                    refreshExpiresIn: refreshExpiresIn
                )

                // Update authentication state
                self.isAuthenticated = true
                print("🔐 AUTH: Authentication state set to true")

                // Fetch user profile
                await fetchUserProfile()
                
                // Close WebView
                self.closeWebView()
                self.webView?.navigationDelegate = nil
                self.webView = nil
            } catch {
                logger.error("Failed to save credentials: \(error)")
            }
        }
    }

    /// Exchanges the authorization code for an access token
    /// - Parameter code: The authorization code received from the OAuth provider
    private func exchangeCodeForToken(code: String) {
        self.logger.info("Exchanging authorization code for token")
        let tokenURLString = "\(AppConfig.BACKEND_API_URL)/api/v1/login/google?code=\(code)"
        guard let tokenURL = URL(string: tokenURLString) else {
            self.logger.error("Invalid token URL: \(tokenURLString)")
            return
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "GET"
        request.addValue(AppConfig.API_KEY, forHTTPHeaderField: "X-API-Key")
        request.addValue("application/json", forHTTPHeaderField: "accept")

        self.logger.info("Sending token exchange request to: \(tokenURL)")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Token exchange error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                self.logger.error("No data received from token exchange")
                return
            }

            self.logger.info("Received response from token exchange")
            // Decode the response
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                self.logger.info("Successfully decoded token response")
                DispatchQueue.main.async {
                    self.handleTokenResponse(tokenResponse)
                }
            } catch {
                self.logger.error("Failed to decode token response: \(error.localizedDescription)")
            }
        }.resume()
    }

    /// Handles the token response after successful exchange
    /// - Parameter tokenResponse: The decoded token response
    private func handleTokenResponse(_ tokenResponse: TokenResponse) {
        Task { @MainActor in
            TokenManager.shared.setTokens(
                accessToken: tokenResponse.access_token,
                refreshToken: tokenResponse.refresh_token,
                expiresIn: TimeInterval(tokenResponse.expires_in),
                refreshExpiresIn: TimeInterval(tokenResponse.refresh_token_expires_in)
            )
            self.isAuthenticated = true

            do {
                try AuthUtils.saveToKeychain(key: "userId", data: "\(tokenResponse.user_id)")
            } catch {
                logger.error("Failed to save userId to keychain: \(error)")
            }

            // Fetch user profile
            await fetchUserProfile()

            // Close any existing WebView window
            self.closeWebView()
            self.webView?.navigationDelegate = nil
            self.webView = nil

            // Notify observers that authentication is complete
            NotificationCenter.default.post(name: .authenticationCompleted, object: nil)
        }
    }

    /// Fetches the user profile information using the access token
    private func fetchUserProfile() async {
        print("🔐 AUTH: Fetching user profile")
        do {
            let accessToken = try await TokenManager.shared.getValidToken()
            
            // Handle the optional return from loadFromKeychain
            guard let userIdString = AuthUtils.loadFromKeychain(key: "userId"),
                  let userId = Int(userIdString) else {
                print("User ID not found or invalid")
                return
            }

            let userInfoURLString = "\(AppConfig.BACKEND_API_URL)/api/v1/users/\(userId)"
            guard let userInfoURL = URL(string: userInfoURLString) else {
                print("Invalid user info URL: \(userInfoURLString)")
                return
            }

            var request = URLRequest(url: userInfoURL)
            request.httpMethod = "GET"
            try await AuthUtils.addAuthHeader(to: &request)

            // Log the full request details for debugging
            print("--- User Profile Request Details ---")
            print("URL: \(request.url?.absoluteString ?? "nil")")
            print("Method: \(request.httpMethod ?? "nil")")
            print("Headers:")
            request.allHTTPHeaderFields?.forEach { key, value in
                print("  \(key): \(value)")
            }
            print("------------------------------------")

            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log response details for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                print("Response Headers:")
                httpResponse.allHeaderFields.forEach { key, value in
                    print("  \(key): \(value)")
                }
            }

            print("Received user profile data")
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw user profile response: \(rawResponse)")
            }
            
            // Decode user profile
            let userProfile = try JSONDecoder().decode(UserProfile.self, from: data)
            print("Successfully decoded user profile")
            print("User ID: \(userProfile.id)")
            print("Username: \(userProfile.username)")
            
            await MainActor.run {
                self.currentUser = userProfile
                self.isAuthenticated = true
                print("Updated current user and authentication state")
                NotificationCenter.default.post(name: .authenticationCompleted, object: nil)
            }
        } catch {
            print("Error retrieving valid token: \(error)")
            await MainActor.run {
                self.isAuthenticated = false
                NotificationCenter.default.post(name: .authenticationCompleted, object: nil)
            }
        }
    }

    /// Signs out the current user
    func signOut() {
        // Clear tokens and user data
        TokenManager.shared.clearTokens()
        AuthUtils.deleteFromKeychain(key: "userId")
        UserDefaults.standard.removeObject(forKey: "currentUserProfile")
        self.currentUser = nil
        self.isAuthenticated = false

        // Mark that this is not a first-time user anymore
        self.isFirstTimeUser = false

        // Notification removed
    }

    // Add a method to complete first-time authentication
    func completeFirstTimeAuthentication() {
        self.isFirstTimeUser = false
        UserDefaults.standard.hasCompletedOnboarding = true
        print("🔐 First-time authentication completed")
    }

    override init() {
        super.init()
        loadUserProfile()
        loadAccountStatus()
    }
    
    private func saveUserProfile(_ user: UserProfile) {
        do {
            let encoder = JSONEncoder()
            let userData = try encoder.encode(user)
            UserDefaults.standard.set(userData, forKey: "currentUserProfile")
        } catch {
            logger.error("Failed to save user profile: \(error.localizedDescription)")
        }
    }
    
    private func loadUserProfile() {
        if let userData = UserDefaults.standard.data(forKey: "currentUserProfile") {
            do {
                let decoder = JSONDecoder()
                let user = try decoder.decode(UserProfile.self, from: userData)
                self.currentUser = user
                self.isAuthenticated = true
            } catch {
                logger.error("Failed to load user profile: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    func ensureUserDataLoaded() async {
        if isAuthenticated && currentUser != nil {
            await fetchUserProfile()
            // Add any other data loading methods here, such as loading chats
            // Perform any necessary post-login tasks here
        }
    }

    @MainActor
    private func closeWebView() {
        #if os(macOS)
        self.authWindow?.close()
        self.authWindow = nil
        self.logger.info("Closed WebView window (macOS)")
        #else
        self.webView?.window?.rootViewController?.dismiss(animated: true, completion: nil)
        self.logger.info("Dismissed WebView (iOS)")
        #endif
    }

    // Add new method to save account status
    private func saveAccountStatus(_ status: AccountStatus) {
        do {
            let encoder = JSONEncoder()
            let statusData = try encoder.encode(status)
            UserDefaults.standard.set(statusData, forKey: "accountStatus")
            print("📊 Saved account status: \(status)")
        } catch {
            logger.error("Failed to save account status: \(error)")
        }
    }

    // Add method to load account status
    private func loadAccountStatus() {
        if let statusData = UserDefaults.standard.data(forKey: "accountStatus") {
            do {
                let decoder = JSONDecoder()
                let status = try decoder.decode(AccountStatus.self, from: statusData)
                self.accountStatus = status
            } catch {
                logger.error("Failed to load account status: \(error)")
            }
        }
    }

    var isSubscriptionActive: Bool {
        return accountStatus?.subscription_status == "active"
    }
    
    var remainingUsage: Int {
        guard let status = accountStatus else { return 0 }
        guard let limit = status.limit else { return Int.max }
        return max(0, limit - status.current_usage)
    }
    
    var usagePercentage: Double {
        guard let status = accountStatus,
              let limit = status.limit,
              limit > 0 else { return 0 }
        return Double(status.current_usage) / Double(limit)
    }
}

// MARK: - WKNavigationDelegate

extension AuthenticationManager: WKNavigationDelegate {
    /// Decides whether to allow or cancel a navigation
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            logger.info("WebView navigating to: \(url)")
            
            // Check if the URL matches our custom scheme for OAuth redirect
            if url.scheme == "com.dial8.oauth" {
                logger.info("Detected redirect to app's custom scheme")
                handleAuthRedirect(url: url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    /// Handles navigation failures
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.logger.error("WebView failed to load: \(error.localizedDescription)")
    }

    /// Handles successful navigation
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.logger.info("WebView finished loading")
    }
}

// MARK: - Models

/// Represents the response from a token exchange
struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token_expires_in: Int
    let user_id: Int
    let account_status: AccountStatus?
}

/// Represents a user's profile information
struct UserProfile: Codable {
    let id: Int
    let email: String
    let username: String
    let provider: String
    let provider_id: String
    let created_at: String
    let last_login: String?
    let preferences: String?
}

extension AuthenticationManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.presentationAnchor ?? ASPresentationAnchor()
    }
}

/// Add AccountStatus struct
struct AccountStatus: Codable {
    let type: String
    let subscription_status: String
    let current_usage: Int
    let limit: Int?
    let period_start: String?
    let period_end: String?
    let last_sync: String?
}

