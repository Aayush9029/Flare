import Dependencies
import DependenciesMacros
import Foundation
import Security

/// The license key is the one secret worth Keychain protection: unlike the OAuth
/// token it is not re-obtainable by signing in again, and a plist is user-editable.
@DependencyClient
public struct LicenseStore: Sendable {
    public var key: @Sendable () -> String?
    public var activationID: @Sendable () -> String?
    public var save: @Sendable (String, String?) throws -> Void
    public var clear: @Sendable () throws -> Void
}

extension LicenseStore: DependencyKey {
    private static let service = "ca.optimalapps.flare.license"

    public static let liveValue = Self(
        key: { read("key") },
        activationID: { read("activation") },
        save: { key, activationID in
            try write("key", key)
            if let activationID { try write("activation", activationID) }
        },
        clear: {
            for account in ["key", "activation"] {
                SecItemDelete([
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                ] as CFDictionary)
            }
        }
    )

    private static func read(_ account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ account: String, _ value: String) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let data = Data(value.utf8)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var query = base
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

extension LicenseStore: TestDependencyKey {
    public static let testValue = Self.ephemeral()

    public static func ephemeral(key: String? = nil, activationID: String? = nil) -> Self {
        let box = LockedBox((key: key, activation: activationID))
        return Self(
            key: { box.value.key },
            activationID: { box.value.activation },
            save: { key, activation in box.value = (key, activation ?? box.value.activation) },
            clear: { box.value = (nil, nil) }
        )
    }
}

public extension DependencyValues {
    var licenseStore: LicenseStore {
        get { self[LicenseStore.self] }
        set { self[LicenseStore.self] = newValue }
    }
}
