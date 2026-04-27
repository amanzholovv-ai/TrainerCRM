import Foundation
import Security

// MARK: - KeychainHelper
// Безопасное хранилище для чувствительных данных (email, токены).
// Использует iOS Keychain вместо UserDefaults.

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let service = Bundle.main.bundleIdentifier ?? "com.trainercrm.app"

    // MARK: - Сохранение

    @discardableResult
    func set(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Сначала удаляем старую запись (обновление через update ненадёжно на всех iOS)
        delete(forKey: key)

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Чтение

    func get(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    // MARK: - Удаление

    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Ключи

extension KeychainHelper {
    enum Key {
        static let savedEmail = "savedEmail"
    }
}
