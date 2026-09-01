import Dependencies
import DependenciesMacros
import Foundation

/// Which credential the user chose. `.automatic` prefers an API key when one is
/// configured, which is the behaviour most people expect after adding a key.
public enum CredentialPreference: String, CaseIterable, Sendable {
    case automatic
    case chatgpt
    case apiKey

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .chatgpt: "ChatGPT"
        case .apiKey: "API Key"
        }
    }

    public var detail: String {
        switch self {
        case .automatic: "Uses the API key when one is set, otherwise ChatGPT."
        case .chatgpt: "Answers through your ChatGPT subscription. No extra billing."
        case .apiKey: "Answers through api.openai.com and bills per token."
        }
    }
}

public enum Credentials: Sendable, Equatable {
    case apiKey(String)
    case chatgpt(AuthTokens)
}

@DependencyClient
public struct APIKeyStore: Sendable {
    public var load: @Sendable () -> String?
    public var save: @Sendable (String) throws -> Void
    public var clear: @Sendable () throws -> Void
    /// Reads `OPENAI_API_KEY` out of the user's login shell.
    public var readFromLoginShell: @Sendable () throws -> String
}

extension APIKeyStore: DependencyKey {
    public static let url = URL.applicationSupportDirectory
        .appending(path: "Flare", directoryHint: .isDirectory)
        .appending(path: "api-key")

    public static let liveValue = Self(
        load: {
            // The stored file is the only source of truth. The environment is an
            // import source only, or "Remove Key" could not remove anything.
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? nil : key
        },
        save: { key in
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try Data(key.utf8).write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        },
        clear: {
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            try FileManager.default.removeItem(at: url)
        },
        readFromLoginShell: {
            if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
                return key
            }
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-lic", #"printf %s "$OPENAI_API_KEY""#]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let key = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { throw AuthError.noEnvironmentKey }
            return key
        }
    )
}

extension APIKeyStore: TestDependencyKey {
    public static let testValue = Self.ephemeral()

    public static func ephemeral(_ initial: String? = nil) -> Self {
        let box = LockedBox(initial)
        return Self(
            load: { box.value },
            save: { box.value = $0 },
            clear: { box.value = nil },
            readFromLoginShell: { throw AuthError.noEnvironmentKey }
        )
    }
}

public extension DependencyValues {
    var apiKeyStore: APIKeyStore {
        get { self[APIKeyStore.self] }
        set { self[APIKeyStore.self] = newValue }
    }
}

final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    init(_ value: Value) { stored = value }

    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
