import Foundation
import Security

enum AuthError: Error {
    case noAccessToken
    case noRefreshToken
    case keychainError(OSStatus)
    case serverError
    case invalidResponse
    case tokenExpired
    case refreshTokenExpired
    case malformedToken
    case unknown
    
    var isUnauthorized: Bool {
        switch self {
        case .tokenExpired, .refreshTokenExpired:
            return true
        default:
            return false
        }
    }
}

private let TeamIdentifier = "2725SDV2L5" // Replace with your actual team ID from Apple Developer account

class AuthUtils {
    static func addAuthHeader(to request: inout URLRequest) async throws {
        let validToken = try await TokenManager.shared.getValidToken()
        request.addValue("Bearer \(validToken)", forHTTPHeaderField: "Authorization")
        request.addValue(AppConfig.API_KEY, forHTTPHeaderField: "X-API-Key")
    }

    static func saveToKeychain(key: String, data: String) throws {
        guard let dataToStore = data.data(using: .utf8) else {
            print("❌ Failed to encode data for keychain storage: \(key)")
            throw AuthError.keychainError(errSecParam)
        }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Bundle.main.bundleIdentifier ?? "com.dial8.oauth",
            kSecAttrAccount: key,
            kSecValueData: dataToStore,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccessGroup: "\(TeamIdentifier).com.dial8.oauth"
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("❌ Failed to save to keychain: \(key) with status: \(status)")
            throw AuthError.keychainError(status)
        }
        print("✅ Successfully saved to keychain: \(key)")
    }
    
    static func loadFromKeychain(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Bundle.main.bundleIdentifier ?? "com.dial8.oauth",
            kSecAttrAccount: key,
            kSecAttrAccessGroup: "\(TeamIdentifier).com.dial8.oauth",
            kSecReturnData: kCFBooleanTrue,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }

    static func deleteFromKeychain(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Bundle.main.bundleIdentifier ?? "com.dial8.oauth",
            kSecAttrAccount: key,
            kSecAttrAccessGroup: "\(TeamIdentifier).com.dial8.oauth"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
