import Foundation
import Security

/// Manages API keys in the macOS Keychain.
enum KeychainService {
    private static let serviceName = "me.ajot.arcade"

    /// Save an API key for a provider.
    static func saveKey(_ key: String, for provider: String) throws {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieve an API key for a provider.
    static func getKey(for provider: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete an API key for a provider.
    static func deleteKey(for provider: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: provider,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Check which providers have keys stored.
    static func storedProviders(from allProviders: [String]) -> Set<String> {
        var result = Set<String>()
        for provider in allProviders {
            if getKey(for: provider) != nil {
                result.insert(provider)
            }
        }
        return result
    }

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Keychain save failed with status \(status)"
            }
        }
    }
}
