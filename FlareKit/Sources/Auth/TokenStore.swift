import Dependencies
import DependenciesMacros
import Foundation
import Security
import os

@DependencyClient
public struct TokenStore: Sendable {
    public var load: @Sendable () -> AuthTokens?
    public var save: @Sendable (AuthTokens) throws -> Void
    public var clear: @Sendable () throws -> Void
}

extension TokenStore: DependencyKey {
    public static let liveValue = Self(
        load: {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data
            else { return nil }
            return try? JSONDecoder.tokens.decode(AuthTokens.self, from: data)
        },
        save: { tokens in
            let data = try JSONEncoder.tokens.encode(tokens)
            let status = SecItemUpdate(
                baseQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            if status == errSecItemNotFound {
                var query = baseQuery
                query[kSecValueData as String] = data
                query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
                try check(SecItemAdd(query as CFDictionary, nil))
            } else {
                try check(status)
            }
        },
        clear: {
            let status = SecItemDelete(baseQuery as CFDictionary)
            if status != errSecItemNotFound { try check(status) }
        }
    )

    private static let baseQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "art.aayush.Flare.openai-auth",
        kSecAttrAccount as String: "chatgpt",
    ]

    private static func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}

extension TokenStore: TestDependencyKey {
    public static let testValue = Self()

    /// In-memory store for previews and tests.
    public static func ephemeral(_ initial: AuthTokens? = nil) -> Self {
        let box = OSAllocatedUnfairLock(initialState: initial)
        return Self(
            load: { box.withLock { $0 } },
            save: { tokens in box.withLock { $0 = tokens } },
            clear: { box.withLock { $0 = nil } }
        )
    }
}

public extension DependencyValues {
    var tokenStore: TokenStore {
        get { self[TokenStore.self] }
        set { self[TokenStore.self] = newValue }
    }
}

private extension JSONDecoder {
    static let tokens: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let tokens: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
