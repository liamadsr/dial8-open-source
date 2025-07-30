/// TokenManager handles secure storage and lifecycle management of authentication tokens.
///
/// This singleton service provides comprehensive token management:
///
/// Core Features:
/// - Secure token storage using Keychain
/// - Automatic token refresh before expiration
/// - Access and refresh token lifecycle management
/// - Token validation and expiration handling
///
/// Security Measures:
/// - Secure storage in Keychain
/// - Refresh threshold of 5 minutes before expiration
/// - Automatic token cleanup on logout
/// - Proper error handling for token-related issues
///
/// Managed Token Types:
/// - Access Token: Short-lived authentication token
/// - Refresh Token: Long-lived token for obtaining new access tokens
/// - Expiration Timestamps: For both access and refresh tokens
///
/// API Integration:
/// - Handles token refresh via /api/v1/auth/refresh-token
/// - Manages API key authentication
/// - Provides valid tokens for API requests
///
/// Error Handling:
/// - Custom AuthError types for specific failures
/// - Comprehensive logging for debugging
/// - Graceful handling of token expiration
///
/// Usage:
/// ```swift
/// let manager = TokenManager.shared
///
/// // Get a valid token
/// let token = try await manager.getValidToken()
///
/// // Set new tokens
/// manager.setTokens(
///     accessToken: "access_token",
///     refreshToken: "refresh_token",
///     expiresIn: 3600
/// )
///
/// // Clear tokens on logout
/// manager.clearTokens()
/// ```

import Foundation

class TokenManager {
    static let shared = TokenManager()
    private let refreshThreshold: TimeInterval = 300 // 5 minutes
    
    // Keys for keychain storage
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    private let expirationKey = "tokenExpiration"
    private let refreshTokenExpirationKey = "refreshTokenExpiration"
    
    private var accessToken: String?
    private var refreshToken: String?
    private var expirationDate: Date?
    private var refreshTokenExpirationDate: Date?
    
    private init() {
        print("🔐 Initializing TokenManager")
        loadTokens()
    }
    
    func setTokens(accessToken: String, refreshToken: String?, expiresIn: TimeInterval, refreshExpiresIn: TimeInterval? = nil) {
        print("💾 Setting new tokens...")
        print("📝 Access token length: \(accessToken.count)")
        print("📝 Refresh token present: \(refreshToken != nil)")
        print("📝 Expires in: \(expiresIn) seconds")
        
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expirationDate = Date().addingTimeInterval(expiresIn)
        
        if let refreshExpiresIn = refreshExpiresIn {
            self.refreshTokenExpirationDate = Date().addingTimeInterval(refreshExpiresIn)
            try? AuthUtils.saveToKeychain(key: refreshTokenExpirationKey, data: refreshTokenExpirationDate!.timeIntervalSince1970.description)
        }
        
        do {
            try AuthUtils.saveToKeychain(key: accessTokenKey, data: accessToken)
            print("✅ Saved access token to keychain")
            
            if let refreshToken = refreshToken {
                try AuthUtils.saveToKeychain(key: refreshTokenKey, data: refreshToken)
                print("✅ Saved refresh token to keychain")
            } else {
                print("⚠️ No refresh token provided")
            }
            
            try AuthUtils.saveToKeychain(key: expirationKey, data: expirationDate!.timeIntervalSince1970.description)
            print("✅ Saved expiration date to keychain")
        } catch {
            print("❌ Failed to save tokens to keychain: \(error)")
        }
    }
    
    private func loadTokens() {
        print("📂 Loading tokens from keychain...")
        
        // Load access token
        accessToken = AuthUtils.loadFromKeychain(key: accessTokenKey)
        print("🔑 Access token: \(accessToken?.prefix(10) ?? "nil")...")
        
        // Load refresh token
        refreshToken = AuthUtils.loadFromKeychain(key: refreshTokenKey)
        print("🔄 Refresh token: \(refreshToken?.prefix(10) ?? "nil")...")
        
        // Load expiration
        if let expirationString = AuthUtils.loadFromKeychain(key: expirationKey),
           let expirationTimeInterval = TimeInterval(expirationString) {
            expirationDate = Date(timeIntervalSince1970: expirationTimeInterval)
            print("📅 Expiration date: \(expirationDate?.description ?? "nil")")
            
            // Check if token is already expired
            if let expDate = expirationDate {
                let timeUntilExpiration = expDate.timeIntervalSince(Date())
                print("⏰ Time until expiration: \(timeUntilExpiration) seconds")
            }
        } else {
            print("⚠️ No expiration date found in keychain")
        }
        
        // Load refresh token expiration
        if let refreshExpirationString = AuthUtils.loadFromKeychain(key: refreshTokenExpirationKey),
           let refreshExpirationTimeInterval = TimeInterval(refreshExpirationString) {
            refreshTokenExpirationDate = Date(timeIntervalSince1970: refreshExpirationTimeInterval)
            print("📅 Refresh token expiration date: \(refreshTokenExpirationDate?.description ?? "nil")")
        } else {
            print("⚠️ No refresh token expiration date found in keychain")
        }
        
        // Validate loaded tokens
        if accessToken == nil {
            print("⚠️ No access token found in keychain")
        }
        if refreshToken == nil {
            print("⚠️ No refresh token found in keychain")
        }
    }
    
    func getValidToken() async throws -> String {
        print("🎫 Getting valid token...")
        
        // First check if we have a refresh token
        guard let refreshToken = refreshToken else {
            print("❌ No refresh token available")
            throw AuthError.noRefreshToken
        }
        
        // Check if we need to refresh
        if let expirationDate = expirationDate {
            print("⏰ Current time: \(Date())")
            print("⏰ Token expires: \(expirationDate)")
            
            if Date() > expirationDate.addingTimeInterval(-refreshThreshold) {
                print("🔄 Token needs refresh")
                return try await refreshAccessToken()
            }
        } else {
            print("⚠️ No expiration date, attempting refresh")
            return try await refreshAccessToken()
        }
        
        // If we have a valid access token, use it
        if let accessToken = accessToken {
            print("✅ Using existing access token")
            return accessToken
        }
        
        // If we get here, we need to refresh
        print("🔄 No valid access token, attempting refresh")
        return try await refreshAccessToken()
    }
    
    private struct RefreshTokenResponse: Codable {
        let access_token: String
        let refresh_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token_expires_in: Int
    }
    
    private func refreshAccessToken() async throws -> String {
        print("🔄 Starting token refresh...")
        guard let refreshToken = refreshToken else {
            print("❌ No refresh token found")
            throw AuthError.noRefreshToken
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = ""
        components.path = ""
        
        guard let url = components.url else {
            print("❌ Invalid URL configuration")
            throw URLError(.badURL)
        }
        
        print("🔗 Refresh URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(AppConfig.API_KEY, forHTTPHeaderField: "X-API-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add refresh token to request body
        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Raw refresh token response: \(responseString)")
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ Server returned error status: \(httpResponse.statusCode)")
            switch httpResponse.statusCode {
            case 401:
                clearTokens()
                throw AuthError.tokenExpired
            case 422:
                throw AuthError.malformedToken
            default:
                throw AuthError.serverError
            }
        }
        
        do {
            let tokenResponse = try JSONDecoder().decode(RefreshTokenResponse.self, from: data)
            setTokens(
                accessToken: tokenResponse.access_token,
                refreshToken: tokenResponse.refresh_token,
                expiresIn: TimeInterval(tokenResponse.expires_in),
                refreshExpiresIn: TimeInterval(tokenResponse.refresh_token_expires_in)
            )
            return tokenResponse.access_token
        } catch {
            print("❌ Failed to decode token response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }
            throw AuthError.invalidResponse
        }
    }
    
    func clearTokens() {
        print("🗑️ Clearing all tokens...")
        self.accessToken = nil
        self.refreshToken = nil
        self.expirationDate = nil
        self.refreshTokenExpirationDate = nil
        
        AuthUtils.deleteFromKeychain(key: accessTokenKey)
        AuthUtils.deleteFromKeychain(key: refreshTokenKey)
        AuthUtils.deleteFromKeychain(key: expirationKey)
        AuthUtils.deleteFromKeychain(key: refreshTokenExpirationKey)
        print("✅ All tokens cleared")
    }
}
