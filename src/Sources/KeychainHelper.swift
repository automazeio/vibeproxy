import Foundation
import Security

/// Helper class for managing secure storage in macOS Keychain
class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.vibeproxy.management"
    private let account = "management-api-key"

    private init() {}

    /// Retrieve the management API key from Keychain
    /// - Returns: The stored key, or nil if not found
    func getManagementKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Store a management API key in Keychain
    /// - Parameter key: The key to store
    /// - Returns: true if successful, false otherwise
    func setManagementKey(_ key: String) -> Bool {
        let data = key.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete the management API key from Keychain
    /// - Returns: true if successful (or item didn't exist), false otherwise
    func deleteManagementKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Generate a cryptographically random management key
    /// - Returns: A random 32-byte hex string (64 characters)
    func generateRandomKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Get or create the management key
    /// - Returns: The existing key from Keychain, or a new generated key
    func getOrCreateManagementKey() -> String {
        if let existingKey = getManagementKey(), !existingKey.isEmpty {
            return existingKey
        }

        // Generate and store a new key
        let newKey = generateRandomKey()
        _ = setManagementKey(newKey)
        return newKey
    }
}
