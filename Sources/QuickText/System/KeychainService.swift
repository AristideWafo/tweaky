import Foundation
import Security

enum KeychainService {
    private static let service = "com.quicktext.app"

    static func saveAPIKey(_ value: String, for provider: AIProviderID) throws {
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        let data = Data(value.utf8)
        let updateStatus = SecItemUpdate(identity as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError.saveFailed }
        var insert = identity
        insert[kSecValueData as String] = data
        guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw KeychainError.saveFailed }
    }

    static func apiKey(for provider: AIProviderID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError.readFailed }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAPIKey(for provider: AIProviderID) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: provider.rawValue]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.deleteFailed }
    }
}

enum KeychainError: Error { case saveFailed, readFailed, deleteFailed }
