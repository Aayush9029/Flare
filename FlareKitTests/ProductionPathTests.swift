import Dependencies
import Foundation
import Testing

@testable import FlareKit

@Suite(
    "Production path",
    .enabled(if: ProcessInfo.processInfo.environment["FLARE_LIVE_TESTS"] != nil),
    .serialized
)
struct ProductionPathTests {
    private func liveAuth() -> OpenAIAuthClient {
        withDependencies {
            $0.tokenStore = .liveValue
            $0.apiKeyStore = .ephemeral()
        } operation: {
            OpenAIAuthClient.liveValue
        }
    }

    private func liveChat(auth: OpenAIAuthClient, apiKey: String? = nil) -> ChatClient {
        withDependencies {
            $0.openAIAuth = auth
            $0.apiKeyStore = .ephemeral(apiKey)
            $0.providerStore = .ephemeral()
        } operation: {
            ChatClient.liveValue
        }
    }

    private func text(of chat: ChatClient, _ request: ChatRequest) async throws -> String {
        var text = ""
        for try await event in try await chat.stream(request) {
            if case .outputTextDelta(let delta) = event { text += delta }
        }
        return text
    }

    @Test("Streams through the API-key credential against the public API")
    func apiKeyPath() async throws {
        // Either source is fine; the stored file is what the app itself reads.
        let key = try #require(
            ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? APIKeyStore.liveValue.load(),
            "set OPENAI_API_KEY or store a key to exercise this path"
        )
        let chat = liveChat(auth: liveAuth(), apiKey: key)
        let text = try await text(
            of: chat,
            ChatRequest(
                endpoint: .openAI,
                model: ChatModelCatalog.default.id,
                effort: "medium",
                instructions: "Be terse.",
                turns: [ChatTurn(role: "user", text: "Reply with exactly: PONG")]
            )
        )
        #expect(text.contains("PONG"))
    }

    @Test("Streams with the settings the app actually sends")
    func appConfiguration() async throws {
        let auth = liveAuth()
        try #require(auth.isSignedIn(), "sign in first, or run importFromCodexCLI")

        let chat = liveChat(auth: auth)
        let preferences = await Preferences()
        let model = await preferences.selectedModel
        let effort = await preferences.reasoningEffort
        let prompt = await preferences.systemPrompt

        let text = try await text(
            of: chat,
            ChatRequest(
                endpoint: .chatGPT,
                model: model,
                effort: effort,
                instructions: prompt,
                turns: [ChatTurn(role: "user", text: "Reply with exactly: PONG")]
            )
        )
        #expect(text.contains("PONG"))
    }

    @Test("Replaying an assistant turn is accepted")
    func multiTurn() async throws {
        let auth = liveAuth()
        try #require(auth.isSignedIn())
        let chat = liveChat(auth: auth)

        let text = try await text(
            of: chat,
            ChatRequest(
                endpoint: .chatGPT,
                model: ChatModelCatalog.default.id,
                effort: "medium",
                instructions: Preferences.defaultSystemPrompt,
                turns: [
                    ChatTurn(role: "user", text: "Say A"),
                    ChatTurn(role: "assistant", text: "A"),
                    ChatTurn(role: "user", text: "Reply with exactly: PONG"),
                ]
            )
        )
        #expect(text.contains("PONG"))
    }

    @Test("Web search runs and the backend reports it")
    func webSearchRuns() async throws {
        let auth = liveAuth()
        try #require(auth.isSignedIn())
        let chat = liveChat(auth: auth)

        var searched = false
        var text = ""
        for try await event in try await chat.stream(
            ChatRequest(
                endpoint: .chatGPT,
                model: ChatModelCatalog.default.id,
                effort: "low",
                instructions: "Use the web when the answer depends on current facts.",
                turns: [ChatTurn(role: "user", text: "Search the web for the current Swift release and answer in one line.")],
                webSearch: true
            )
        ) {
            switch event {
            case .webSearchStarted: searched = true
            case .outputTextDelta(let delta): text += delta
            default: break
            }
        }
        #expect(searched, "the backend never reported a web_search_call")
        #expect(!text.isEmpty)
    }

    @Test("Every model and effort the settings expose is accepted")
    func everyModelAndEffort() async throws {
        let auth = liveAuth()
        try #require(auth.isSignedIn())
        let chat = liveChat(auth: auth)

        for option in ChatModelCatalog.all {
            for effort in option.efforts {
                let text = try await text(
                    of: chat,
                    ChatRequest(
                        endpoint: .chatGPT,
                        model: option.id,
                        effort: effort,
                        instructions: "Be terse.",
                        turns: [ChatTurn(role: "user", text: "hi")]
                    )
                )
                #expect(!text.isEmpty, "\(option.id) / \(effort) returned nothing")
            }
        }
    }

    @Test("Claude answers through the Messages API with the stored key")
    func anthropicPath() async throws {
        guard let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ProviderStore.liveValue.load().key(for: "anthropic"),
              !key.isEmpty
        else {
            print("skipping Claude: set ANTHROPIC_API_KEY or store a key")
            return
        }
        let chat = withDependencies {
            $0.openAIAuth = .testValue
            $0.apiKeyStore = .ephemeral()
            $0.providerStore = .ephemeral(ProviderFile(keys: ["anthropic": key]))
        } operation: {
            ChatClient.liveValue
        }
        let models = try await ProviderClient.liveValue.listModels(.anthropic, key)
        let haiku = try #require(models.first { $0.id.contains("haiku") }?.id)
        let sonnet = models.first { $0.id.hasPrefix("claude-sonnet-5-5") }?.id ?? haiku

        for (model, effort) in [(haiku, nil), (sonnet, Effort.medium)] {
            var text = ""
            var reasoned = false
            for try await event in try await chat.stream(
                ChatRequest(
                    endpoint: .anthropic,
                    model: model,
                    effort: effort,
                    instructions: "Be terse.",
                    turns: [ChatTurn(role: "user", text: "Reply with exactly: PONG")]
                )
            ) {
                switch event {
                case .outputTextDelta(let delta): text += delta
                case .reasoningSummaryDelta: reasoned = true
                default: break
                }
            }
            #expect(text.contains("PONG"), "\(model) returned \(text)")
            #expect(reasoned == (effort != nil), "\(model) thinking mismatch")
        }
    }
}
