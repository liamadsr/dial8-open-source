import Foundation
import Security

class KeychainWrapper {
    static let standard = KeychainWrapper()

    func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        // Create query
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as CFDictionary

        // Add or update item
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }

    func string(forKey key: String) -> String? {
        // Create query
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        return nil
    }

    func removeObject(forKey key: String) {
        // Create query
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as CFDictionary

        SecItemDelete(query)
    }
}
