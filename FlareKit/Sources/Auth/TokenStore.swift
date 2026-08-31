import Dependencies
import DependenciesMacros
import Foundation
import os

@DependencyClient
public struct TokenStore: Sendable {
    public var load: @Sendable () -> AuthTokens?
    public var save: @Sendable (AuthTokens) throws -> Void
    public var clear: @Sendable () throws -> Void
}

extension TokenStore: DependencyKey {
    // Keychain ACLs are bound to the signing identity, so every re-signed debug
    // build lost the token. Codex stores its own session as a 0600 file for the
    // same reason; this matches it.
    public static let url = URL.applicationSupportDirectory
        .appending(path: "Flare", directoryHint: .isDirectory)
        .appending(path: "auth.json")

    public static let liveValue = Self(
        load: {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder.tokens.decode(AuthTokens.self, from: data)
        },
        save: { tokens in
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try JSONEncoder.tokens.encode(tokens).write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        },
        clear: {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            try FileManager.default.removeItem(at: url)
        }
    )
}

extension TokenStore: TestDependencyKey {
    public static let testValue = Self()

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
