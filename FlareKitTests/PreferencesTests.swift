import Dependencies
import Foundation
import Testing

@testable import FlareKit

@Suite("Model catalog")
struct ChatModelCatalogTests {
    @Test("Unknown ids fall back to the default model")
    func fallback() {
        #expect(ChatModelCatalog.option(id: "nope").id == ChatModelCatalog.default.id)
    }

    @Test("Known ids resolve")
    func lookup() {
        #expect(ChatModelCatalog.option(id: "gpt-5.6-sol").displayName == "GPT-5.6 Sol")
    }

    @Test("Every model offers at least one effort level")
    func efforts() {
        for option in ChatModelCatalog.all {
            #expect(!option.efforts.isEmpty)
        }
    }
}

@Suite("Provider catalog", .serialized)
@MainActor
struct ProviderCatalogTests {
    private func makeCatalog(
        file: ProviderFile = .empty,
        apiKey: String? = nil,
        listing: [ModelInfo] = [],
        reply: String = "4"
    ) -> ProviderCatalog {
        withDependencies {
            $0.tokenStore = .ephemeral()
            $0.apiKeyStore = .ephemeral(apiKey)
            $0.providerStore = .ephemeral(file)
            $0.providerClient = .listing(listing)
            $0.chatClient = .echo(reply)
            $0.openAIAuth = .testValue
            $0.uuid = .incrementing
            $0.defaultAppStorage = UserDefaults(suiteName: "ProviderCatalogTests-\(UUID().uuidString)")!
        } operation: {
            ProviderCatalog(preferences: Preferences())
        }
    }

    private static let server = CustomProvider(id: UUID(), name: "Desk", baseURL: URL(string: "http://desk.local:8080/v1")!)

    private static let serverFile = ProviderFile(
        models: [server.id.uuidString: [ModelInfo(id: "qwen3", efforts: nil), ModelInfo(id: "plain", efforts: [])]],
        custom: [server]
    )

    @Test("The built-in providers come first, in Compose's order, then endpoints")
    func order() {
        let catalog = makeCatalog(file: Self.serverFile)
        #expect(catalog.providers.map(\.name) == ["ChatGPT", "OpenAI", "Anthropic", "Groq", "Gemini", "OpenRouter", "Desk"])
    }

    @Test("With nothing set up the choice stays but cannot answer")
    func nothingReady() {
        let catalog = makeCatalog()
        #expect(catalog.ready.isEmpty)
        #expect(catalog.active.kind == .chatGPT)
        #expect(!catalog.active.isReady)
    }

    @Test("An unready choice falls back to a provider that can answer")
    func fallsBackToReady() {
        let catalog = makeCatalog(apiKey: "sk-test")
        catalog.activate(ProviderKind.anthropic.rawValue)
        #expect(catalog.active.kind == .openAI)
    }

    @Test("Each provider remembers its own model")
    func rememberedPerProvider() {
        let catalog = makeCatalog(file: Self.serverFile, apiKey: "sk-test")
        let server = Self.server.id.uuidString

        catalog.activate(ProviderKind.openAI.rawValue)
        catalog.select(ModelSelection(model: "gpt-5.6-sol", effort: "xhigh"))
        catalog.activate(server)
        #expect(catalog.selection == ModelSelection(model: "qwen3", effort: nil))
        catalog.select(ModelSelection(model: "qwen3", effort: "high"))

        catalog.activate(ProviderKind.openAI.rawValue)
        #expect(catalog.selection == ModelSelection(model: "gpt-5.6-sol", effort: "xhigh"))
        #expect(catalog.selectionTitle == "5.6 Sol · Extra High")
        catalog.activate(server)
        #expect(catalog.selection == ModelSelection(model: "qwen3", effort: "high"))
        #expect(catalog.selectionTitle == "qwen3 · High")
    }

    @Test("An effort a model cannot take is dropped, not sent; OpenAI always has one")
    func clampsEffort() {
        let catalog = makeCatalog(file: Self.serverFile, apiKey: "sk-test")
        catalog.activate(Self.server.id.uuidString)
        catalog.select(ModelSelection(model: "plain", effort: "high"))
        #expect(catalog.selection.effort == nil)
        #expect(catalog.active.efforts(for: "plain").isEmpty)
        #expect(catalog.active.efforts(for: "unlisted") == Effort.standard)

        catalog.activate(ProviderKind.openAI.rawValue)
        catalog.select(ModelSelection(model: "gpt-5.6-luna", effort: nil))
        #expect(catalog.selection.effort == "medium")
        catalog.select(ModelSelection(model: "gpt-5.6-luna", effort: "xhigh"))
        #expect(catalog.selection.effort == "medium", "Luna stops at medium")
    }

    @Test("A key is kept once the vendor lists models, and they come back sorted")
    func keysListModels() async throws {
        let catalog = makeCatalog(listing: [ModelInfo(id: "b-model"), ModelInfo(id: "a-model")])
        let groq = try #require(catalog.provider(ProviderKind.groq.rawValue))
        try await catalog.setKey("gsk_test", for: groq)
        let ready = try #require(catalog.provider(ProviderKind.groq.rawValue))
        #expect(ready.isReady)
        #expect(ready.models.map(\.id) == ["a-model", "b-model"])
        #expect(catalog.key(for: ready) == "gsk_test")
        #expect(catalog.ready.map(\.name) == ["Groq"])

        try catalog.clearKey(for: ready)
        #expect(catalog.ready.isEmpty)
        #expect(catalog.provider(ProviderKind.groq.rawValue)?.models.isEmpty == true)
    }

    @Test("Adding an endpoint lists its models and makes it usable")
    func addsCustom() async throws {
        let catalog = makeCatalog(listing: [ModelInfo(id: "b-model"), ModelInfo(id: "a-model")])
        let added = try catalog.addCustom(name: "Router", baseURL: URL(string: "https://api.mistral.ai/v1")!)
        let provider = try #require(catalog.provider(added.id.uuidString))
        try await catalog.setKey("or-key", for: provider)
        #expect(catalog.provider(added.id.uuidString)?.models.map(\.id) == ["a-model", "b-model"])
        #expect(catalog.ready.map(\.name) == ["Router"])
        catalog.activate(added.id.uuidString)
        #expect(catalog.selection.model == "a-model")
        #expect(catalog.selectionTitle == "a-model")

        try catalog.removeCustom(added.id)
        #expect(catalog.ready.isEmpty)
        #expect(catalog.file.keys[added.id.uuidString] == nil)
    }

    @Test("An Anthropic key lists models and the default lands on Sonnet")
    func anthropicKey() async throws {
        let catalog = makeCatalog(listing: [
            ModelInfo(id: "claude-opus-5-20260901", name: "Claude Opus 5"),
            ModelInfo(id: "claude-sonnet-5-20260815", name: "Claude Sonnet 5"),
            ModelInfo(id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5"),
        ])
        let anthropic = try #require(catalog.provider(ProviderKind.anthropic.rawValue))
        try await catalog.setKey("sk-ant-test", for: anthropic)
        catalog.activate(anthropic.id)
        #expect(catalog.active.isReady)
        #expect(catalog.selection == ModelSelection(model: "claude-sonnet-5-20260815", effort: nil))
        #expect(catalog.selectionTitle == "Claude Sonnet 5")
        #expect(catalog.active.titleSelection(current: catalog.selection).model == "claude-haiku-4-5-20251001")
        #expect(catalog.active.efforts(for: "claude-opus-5-20260901") == Effort.standard)
    }

    @Test("A typed model must answer a sum before it is trusted")
    func verifiesModel() async throws {
        let catalog = makeCatalog(file: Self.serverFile, reply: "4")
        let desk = try #require(catalog.provider(Self.server.id.uuidString))
        try await catalog.verifyModel("qwen3", for: desk)

        let mute = makeCatalog(file: Self.serverFile, reply: "I cannot")
        let deskAgain = try #require(mute.provider(Self.server.id.uuidString))
        await #expect(throws: ProviderError.self) {
            try await mute.verifyModel("qwen3", for: deskAgain)
        }
    }

    @Test("An endpoint at a vendor with its own card folds into that card")
    func foldsDuplicateEndpoint() {
        let router = CustomProvider(id: UUID(), name: "Router", baseURL: ProviderKind.openRouter.baseURL!)
        let catalog = makeCatalog(file: ProviderFile(
            keys: [router.id.uuidString: "or-key"],
            models: [router.id.uuidString: [ModelInfo(id: "openai/gpt-oss-120b")]],
            custom: [router]
        ))
        #expect(catalog.providers.map(\.name) == ["ChatGPT", "OpenAI", "Anthropic", "Groq", "Gemini", "OpenRouter"])
        let openRouter = catalog.provider(ProviderKind.openRouter.rawValue)
        #expect(openRouter?.isReady == true)
        #expect(openRouter?.models.map(\.id) == ["openai/gpt-oss-120b"])
        #expect(catalog.file.custom.isEmpty)
    }

    @Test("The old credential preference seeds the active provider")
    func migratesCredentialPreference() {
        let defaults = UserDefaults(suiteName: "ProviderCatalogTests-migration-\(UUID().uuidString)")!
        defaults.set("apiKey", forKey: "credentialPreference")
        let catalog = withDependencies {
            $0.tokenStore = .ephemeral()
            $0.apiKeyStore = .ephemeral("sk-test")
            $0.providerStore = .ephemeral()
            $0.providerClient = .listing([])
            $0.chatClient = .echo("")
            $0.openAIAuth = .testValue
            $0.defaultAppStorage = defaults
        } operation: {
            ProviderCatalog(preferences: Preferences())
        }
        #expect(catalog.active.kind == .openAI)
    }

    @Test("The first shape of the provider file still reads")
    func legacyFile() throws {
        let json = """
        {"anthropicKey":"sk-ant-old","anthropicModels":[{"id":"claude-sonnet-5","name":"Claude Sonnet 5"}],
         "custom":[{"id":"5A3C7C2E-1B9D-4C0A-9E6F-1234567890AB","name":"Desk","baseURL":"http://127.0.0.1:8089/v1","apiKey":"k","models":[{"id":"qwen3","name":"qwen3"}]}]}
        """
        let file = try JSONDecoder().decode(ProviderFile.self, from: Data(json.utf8))
        #expect(file.keys["anthropic"] == "sk-ant-old")
        #expect(file.models["anthropic"]?.first?.id == "claude-sonnet-5")
        #expect(file.custom.first?.name == "Desk")
        #expect(file.keys["5A3C7C2E-1B9D-4C0A-9E6F-1234567890AB"] == "k")
        #expect(file.models["5A3C7C2E-1B9D-4C0A-9E6F-1234567890AB"]?.first?.id == "qwen3")
    }
}
