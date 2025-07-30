//
//  StripeService.swift
//  dial8
//
//  Created by Liam Alizadeh on 11/26/24.
//

/// StripeService manages all payment and subscription-related functionality for Dial8.
///
/// This singleton service handles the integration with Stripe's payment platform:
///
/// Core Features:
/// - Checkout Session Creation: Initiates payment flows
/// - Subscription Management: Handles subscription status updates
/// - Customer Portal: Provides access to Stripe's customer portal
/// - Development Tools: Includes subscription reset functionality
///
/// API Endpoints:
/// - POST /api/v1/account/create-checkout-session
/// - POST /api/v1/account/subscription/manual-status
/// - GET /api/v1/account/subscription/portal
/// - POST /api/v1/account/subscription/reset
///
/// Security:
/// - Uses secure HTTPS connections
/// - Implements proper authentication headers
/// - Handles API keys securely
///
/// Error Handling:
/// - Custom StripeError enum for specific error cases
/// - Proper HTTP response validation
/// - Comprehensive error propagation
///
/// Usage:
/// ```swift
/// let service = StripeService.shared
/// 
/// // Create checkout session
/// let checkoutURL = try await service.createCheckoutSession()
/// 
/// // Update subscription status
/// try await service.updateSubscriptionStatus(.active)
/// 
/// // Access customer portal
/// let portalURL = try await service.createPortalSession()
/// ```

import Foundation

enum StripeError: Error {
    case invalidURL
    case invalidResponse
    case checkoutCreationFailed
}

enum SubscriptionStatus: String, CaseIterable {
    case active
    case inactive
    case cancelled
    case past_due
    
    var displayName: String {
        self.rawValue.capitalized
    }
}

class StripeService {
    static let shared = StripeService()
    
    func createCheckoutSession() async throws -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = ""
        components.path = ""
        
        guard let url = components.url else {
            throw StripeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add authentication headers
        try await AuthUtils.addAuthHeader(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.checkoutCreationFailed
        }
        
        struct CheckoutResponse: Codable {
            let url: String
        }
        
        let checkoutResponse = try JSONDecoder().decode(CheckoutResponse.self, from: data)
        return checkoutResponse.url
    }
    
    func updateSubscriptionStatus(_ status: SubscriptionStatus) async throws {
        var components = URLComponents()
        components.scheme = "https"
        components.host = ""
        components.path = ""
        components.queryItems = [
            URLQueryItem(name: "status", value: status.rawValue)
        ]
        
        guard let url = components.url else {
            throw StripeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Add authentication headers
        try await AuthUtils.addAuthHeader(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StripeError.checkoutCreationFailed
        }
        
        // Update local account status
        if let status = try? JSONDecoder().decode(AccountStatus.self, from: data) {
            DispatchQueue.main.async {
                AuthenticationManager.shared.accountStatus = status
            }
        }
    }
    
    func createPortalSession() async throws -> String {
        guard var components = URLComponents(string: "\(AppConfig.BACKEND_API_URL)/api/v1/account/subscription/portal") else {
            throw URLError(.badURL)
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.API_KEY, forHTTPHeaderField: "X-API-Key")
        
        let token = try await TokenManager.shared.getValidToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct PortalResponse: Codable {
            let url: String
        }
        
        let portalResponse = try JSONDecoder().decode(PortalResponse.self, from: data)
        return portalResponse.url
    }
    
    func resetSubscription() async throws {
        guard var components = URLComponents(string: "\(AppConfig.BACKEND_API_URL)/api/v1/account/subscription/reset") else {
            throw URLError(.badURL)
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.API_KEY, forHTTPHeaderField: "X-API-Key")
        
        let token = try await TokenManager.shared.getValidToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
