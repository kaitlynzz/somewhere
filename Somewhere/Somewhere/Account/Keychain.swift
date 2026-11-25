//
//  Keychain.swift
//  Somewhere — tiny wrapper around the iOS Keychain (encrypted, on-device).
//  Muskaan: account data lives here instead of UserDefaults.
//

import Foundation
import Security

enum Keychain {
    private static let service = "com.somewhere.account"

    private static func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    /// Saves (or replaces) data for a key. Only readable on this device, after first unlock.
    @discardableResult
    static func set(_ data: Data, for key: String) -> Bool {
        let query = baseQuery(key)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func data(for key: String) -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }

    // Codable helpers

    @discardableResult
    static func set<T: Encodable>(_ value: T, for key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return set(data, for: key)
    }

    static func value<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = data(for: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
