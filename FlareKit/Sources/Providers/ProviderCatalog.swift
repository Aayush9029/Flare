import Dependencies
import Foundation
import Observation

/// Every provider Flare can talk to, which one answers, and which model each one
/// last used. Selections are remembered per provider, so switching back restores them.
@MainActor
@Observable
public final class ProviderCatalog {
    @ObservationIgnored @Dependency(\.providerStore) private var store
    @ObservationIgnored @Dependency(\.providerClient) private var client
    @ObservationIgnored @Dependency(\.chatClient) private var chatClient
    @ObservationIgnored @Dependency(\.openAIAuth) private var auth
    @ObservationIgnored @Dependency(\.tokenStore) private var tokens
    @ObservationIgnored @Dependency(\.apiKeyStore) private var keys
    @ObservationIgnored @Dependency(\.uuid) private var uuid

    public let preferences: Preferences
    public private(set) var providers: [ProviderInfo] = []
    public private(set) var file = ProviderFile.empty
    public private(set) var chatGPTAccount: Account?

    public init(preferences: Preferences) {
        self.preferences = preferences
        if preferences.activeProvider.isEmpty {
            // Before providers, the preference named a credential; carry that choice over.
            let legacy = preferences.credentialPreferenceRaw == "apiKey" ? ProviderKind.openAI : ProviderKind.chatGPT
            preferences.$activeProvider.withLock { $0 = legacy.rawValue }
        }
        reload()
    }

    public var ready: [ProviderInfo] { providers.filter(\.isReady) }

    /// The chosen provider when it can answer, else the first that can, else the choice itself.
    public var active: ProviderInfo {
        let chosen = providers.first { $0.id == preferences.activeProvider }
        if let chosen, chosen.isReady { return chosen }
        return ready.first ?? chosen ?? providers[0]
    }

    public func provider(_ id: String) -> ProviderInfo? {
        providers.first { $0.id == id }
    }

    public var selection: ModelSelection { selection(for: active) }

    public var selectionTitle: String { active.title(for: selection) }

    public func selection(for provider: ProviderInfo) -> ModelSelection {
        if let remembered = memory[provider.id] { return provider.clamp(remembered) }
        switch provider.kind {
        case .chatGPT, .openAI:
            return provider.clamp(ModelSelection(model: preferences.selectedModel, storedEffort: preferences.reasoningEffort))
        default:
            return provider.defaultSelection
        }
    }

    public func activate(_ id: String) {
        preferences.$activeProvider.withLock { $0 = id }
    }

    public func select(_ selection: ModelSelection, for provider: ProviderInfo? = nil) {
        let provider = provider ?? active
        var memory = memory
        memory[provider.id] = selection
        self.memory = memory
        if provider.kind == .chatGPT || provider.kind == .openAI {
            preferences.$selectedModel.withLock { $0 = selection.model }
            preferences.$reasoningEffort.withLock { $0 = selection.storedEffort }
        }
    }

    private var memory: [String: ModelSelection] {
        get {
            (try? JSONDecoder().decode([String: ModelSelection].self, from: Data(preferences.providerSelections.utf8))) ?? [:]
        }
        set {
            let encoded = (try? JSONEncoder().encode(newValue)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
            preferences.$providerSelections.withLock { $0 = encoded }
        }
    }

    // MARK: Loading

    public func reload() {
        file = foldingBuiltIns(store.load())
        let account = tokens.load()?.account
        chatGPTAccount = account
        let openAIKey = keys.load()

        var list: [ProviderInfo] = []
        for kind in ProviderKind.builtIn {
            let id = kind.rawValue
            switch kind {
            case .chatGPT:
                list.append(
                    ProviderInfo(
                        id: id, kind: kind, name: kind.title,
                        isReady: tokens.load() != nil,
                        caption: account?.email ?? "Subscription",
                        models: Self.openAIModels,
                        endpoint: .chatGPT
                    )
                )
            case .openAI:
                list.append(
                    ProviderInfo(
                        id: id, kind: kind, name: kind.title,
                        isReady: openAIKey != nil,
                        caption: openAIKey.map(Self.masked) ?? "Per token",
                        models: Self.openAIModels,
                        endpoint: .openAI
                    )
                )
            case .anthropic:
                let key = file.key(for: id)
                list.append(
                    ProviderInfo(
                        id: id, kind: kind, name: kind.title,
                        isReady: key != nil,
                        caption: key.map(Self.masked) ?? "Per token",
                        models: file.models[id] ?? [],
                        endpoint: .anthropic
                    )
                )
            case .groq, .gemini, .openRouter:
                let key = file.key(for: id)
                list.append(
                    ProviderInfo(
                        id: id, kind: kind, name: kind.title,
                        isReady: key != nil,
                        caption: key.map(Self.masked) ?? "Per token",
                        models: file.models[id] ?? [],
                        endpoint: .compatible(baseURL: kind.baseURL!, providerID: id)
                    )
                )
            case .compatible:
                break
            }
        }
        for custom in file.custom {
            let id = custom.id.uuidString
            list.append(
                ProviderInfo(
                    id: id, kind: .compatible, name: custom.name,
                    isReady: true,
                    caption: custom.baseURL.host() ?? custom.baseURL.absoluteString,
                    models: file.models[id] ?? [],
                    endpoint: .compatible(baseURL: custom.baseURL, providerID: id)
                )
            )
        }
        providers = list
    }

    /// An endpoint added by hand at a vendor that now has a card of its own moves its
    /// key and models to that card, so nothing is listed twice.
    private func foldingBuiltIns(_ loaded: ProviderFile) -> ProviderFile {
        var file = loaded
        var folded = false
        for custom in loaded.custom {
            guard let kind = ProviderKind.builtIn.first(where: { $0.baseURL == custom.baseURL }) else { continue }
            let id = custom.id.uuidString
            if file.keys[kind.rawValue] == nil, let key = file.keys[id] { file.keys[kind.rawValue] = key }
            if file.models[kind.rawValue] == nil, let models = file.models[id] { file.models[kind.rawValue] = models }
            file.keys[id] = nil
            file.models[id] = nil
            file.custom.removeAll { $0.id == custom.id }
            if preferences.activeProvider == id { preferences.$activeProvider.withLock { $0 = kind.rawValue } }
            folded = true
        }
        if folded { try? store.save(file) }
        return file
    }

    static let openAIModels = ChatModelCatalog.all.map { ModelInfo(id: $0.id, name: $0.displayName, efforts: $0.efforts) }

    public static func masked(_ key: String) -> String {
        guard key.count > 12 else { return String(repeating: "•", count: key.count) }
        return key.prefix(7) + String(repeating: "•", count: 12) + key.suffix(4)
    }

    // MARK: Keys

    /// The stored key for a provider, for the field to show.
    public func key(for provider: ProviderInfo) -> String? {
        switch provider.kind {
        case .chatGPT: nil
        case .openAI: keys.load()
        default: file.key(for: provider.id)
        }
    }

    /// Proves the key against the vendor before keeping it: OpenAI answers a "hi",
    /// everyone else lists their models, which the picker then shows.
    public func setKey(_ key: String, for provider: ProviderInfo) async throws {
        switch provider.kind {
        case .chatGPT:
            return
        case .openAI:
            try await auth.verifyAPIKey(key)
            try auth.setAPIKey(key)
        default:
            let models = try await client.listModels(provider.endpoint, key)
            var file = store.load()
            file.keys[provider.id] = key
            file.models[provider.id] = Self.sorted(models)
            try store.save(file)
        }
        reload()
    }

    public func clearKey(for provider: ProviderInfo) throws {
        switch provider.kind {
        case .chatGPT:
            return
        case .openAI:
            try auth.clearAPIKey()
        default:
            var file = store.load()
            file.keys[provider.id] = nil
            if provider.kind != .compatible { file.models[provider.id] = nil }
            try store.save(file)
        }
        reload()
    }

    public func refreshModels(for provider: ProviderInfo) async throws {
        guard provider.kind != .chatGPT, provider.kind != .openAI else { return }
        let models = try await client.listModels(provider.endpoint, file.key(for: provider.id) ?? "")
        var file = store.load()
        file.models[provider.id] = Self.sorted(models)
        try store.save(file)
        reload()
    }

    /// Asks the model a sum and expects the number back, as Compose does, so a typed
    /// id is known to work before it is relied on.
    public func verifyModel(_ id: String, for provider: ProviderInfo) async throws {
        let answer = try await chatClient.complete(
            ChatRequest(
                endpoint: provider.endpoint,
                model: id,
                effort: nil,
                instructions: "You are a math assistant. Reply with only the numeric answer, nothing else.",
                turns: [ChatTurn(role: "user", text: "What is 2+2?")]
            )
        )
        guard answer.contains("4") else {
            throw ProviderError.failed("\(id) did not answer as expected. Got: \(answer.prefix(80))")
        }
    }

    private static func sorted(_ models: [ModelInfo]) -> [ModelInfo] {
        models.sorted { $0.shortName.localizedCaseInsensitiveCompare($1.shortName) == .orderedAscending }
    }

    // MARK: Custom endpoints

    public func custom(_ id: String) -> CustomProvider? {
        file.custom.first { $0.id.uuidString == id }
    }

    @discardableResult
    public func addCustom(name: String, baseURL: URL) throws -> CustomProvider {
        let provider = CustomProvider(id: uuid(), name: name, baseURL: baseURL)
        var file = store.load()
        file.custom.append(provider)
        try store.save(file)
        reload()
        return provider
    }

    public func updateCustom(_ provider: CustomProvider) throws {
        var file = store.load()
        guard let index = file.custom.firstIndex(where: { $0.id == provider.id }) else { return }
        file.custom[index] = provider
        try store.save(file)
        reload()
    }

    public func removeCustom(_ id: UUID) throws {
        var file = store.load()
        file.custom.removeAll { $0.id == id }
        file.keys[id.uuidString] = nil
        file.models[id.uuidString] = nil
        try store.save(file)
        var memory = memory
        memory[id.uuidString] = nil
        self.memory = memory
        reload()
    }
}
