import Dependencies
import DependenciesMacros
import Foundation

/// Keys and listed models for every provider but ChatGPT and OpenAI, which keep
/// their own files, plus the endpoints the user added. Keyed by provider id.
public struct ProviderFile: Codable, Sendable, Equatable {
    public var keys: [String: String]
    public var models: [String: [ModelInfo]]
    public var custom: [CustomProvider]

    public init(keys: [String: String] = [:], models: [String: [ModelInfo]] = [:], custom: [CustomProvider] = []) {
        self.keys = keys
        self.models = models
        self.custom = custom
    }

    public static let empty = ProviderFile()

    public func key(for id: String) -> String? {
        keys[id].flatMap { $0.isEmpty ? nil : $0 }
    }

    enum CodingKeys: String, CodingKey {
        case keys
        case models
        case custom
        case anthropicKey
        case anthropicModels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keys = try container.decodeIfPresent([String: String].self, forKey: .keys) ?? [:]
        models = try container.decodeIfPresent([String: [ModelInfo]].self, forKey: .models) ?? [:]
        custom = try container.decodeIfPresent([CustomProvider].self, forKey: .custom) ?? []
        // The first shape of this file kept the Anthropic key and each endpoint's key beside them.
        if let legacy = try container.decodeIfPresent(String.self, forKey: .anthropicKey), !legacy.isEmpty {
            keys[ProviderKind.anthropic.rawValue] = legacy
        }
        if let legacy = try container.decodeIfPresent([ModelInfo].self, forKey: .anthropicModels), !legacy.isEmpty {
            models[ProviderKind.anthropic.rawValue] = legacy
        }
        if let legacy = try? container.decodeIfPresent([LegacyCustom].self, forKey: .custom) {
            for entry in legacy {
                if let key = entry.apiKey, !key.isEmpty { keys[entry.id.uuidString] = key }
                if let listed = entry.models, !listed.isEmpty { models[entry.id.uuidString] = listed }
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keys, forKey: .keys)
        try container.encode(models, forKey: .models)
        try container.encode(custom, forKey: .custom)
    }

    private struct LegacyCustom: Decodable {
        let id: UUID
        let apiKey: String?
        let models: [ModelInfo]?
    }
}

@DependencyClient
public struct ProviderStore: Sendable {
    public var load: @Sendable () -> ProviderFile = { .empty }
    public var save: @Sendable (ProviderFile) throws -> Void
}

extension ProviderStore: DependencyKey {
    public static let url = URL.applicationSupportDirectory
        .appending(path: "Flare", directoryHint: .isDirectory)
        .appending(path: "providers.json")

    public static let liveValue = Self(
        load: {
            guard let data = try? Data(contentsOf: url) else { return .empty }
            return (try? JSONDecoder().decode(ProviderFile.self, from: data)) ?? .empty
        },
        save: { file in
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(file).write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    )
}

extension ProviderStore: TestDependencyKey {
    public static let testValue = Self.ephemeral()

    public static func ephemeral(_ initial: ProviderFile = .empty) -> Self {
        let box = LockedBox(initial)
        return Self(
            load: { box.value },
            save: { box.value = $0 }
        )
    }
}

public extension DependencyValues {
    var providerStore: ProviderStore {
        get { self[ProviderStore.self] }
        set { self[ProviderStore.self] = newValue }
    }
}
