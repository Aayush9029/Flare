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

    @Test("The live stores on disk resolve to the API key, not the Codex backend")
    func liveCredentialResolution() async throws {
        let auth = withDependencies {
            $0.tokenStore = .liveValue
            $0.apiKeyStore = .liveValue
        } operation: {
            OpenAIAuthClient.liveValue
        }
        let credential = try await auth.credentials(.automatic)
        guard case .apiKey = credential else {
            Issue.record("resolved to \(credential) — the API key on disk should win")
            return
        }
    }

    @Test("Streams through the API-key credential against the public API")
    func apiKeyPath() async throws {
        // Either source is fine; the stored file is what the app itself reads.
        let key = try #require(
            ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? APIKeyStore.liveValue.load(),
            "set OPENAI_API_KEY or store a key to exercise this path"
        )
        let auth = withDependencies {
            $0.apiKeyStore = .ephemeral(key)
            $0.tokenStore = .ephemeral()
        } operation: {
            OpenAIAuthClient.liveValue
        }
        #expect(auth.isSignedIn())
        guard case .apiKey = try await auth.credentials(.automatic) else {
            Issue.record("expected the API key to take priority")
            return
        }

        let chat = withDependencies { $0.openAIAuth = auth } operation: { ChatClient.liveValue }
        var text = ""
        for try await event in try await chat.stream(
            [ChatTurn(role: "user", text: "Reply with exactly: PONG")],
            ChatModelCatalog.default.id,
            "medium",
            "Be terse.",
            [],
            .automatic,
            UUID()
        ) {
            if case .outputTextDelta(let delta) = event { text += delta }
        }
        #expect(text.contains("PONG"))
    }

    @Test("Streams with the settings the app actually sends")
    func appConfiguration() async throws {
        let auth = liveAuth()
        try #require(auth.isSignedIn(), "sign in first, or run importFromCodexCLI")

        let chat = withDependencies { $0.openAIAuth = auth } operation: { ChatClient.liveValue }
        let preferences = await Preferences()
        let model = await preferences.selectedModel
        let effort = await preferences.effectiveEffort
        let prompt = await preferences.systemPrompt

        var text = ""
        for try await event in try await chat.stream(
            [ChatTurn(role: "user", text: "Reply with exactly: PONG")],
            model,
            effort,
            prompt,
            [],
            .automatic,
            UUID()
        ) {
            if case .outputTextDelta(let delta) = event { text += delta }
        }
        #expect(text.contains("PONG"))
    }

    @Test("Replaying an assistant turn is accepted")
    func multiTurn() async throws {
        let auth = liveAuth()
        try #require(auth.isSignedIn())
        let chat = withDependencies { $0.openAIAuth = auth } operation: { ChatClient.liveValue }

        var text = ""
        for try await event in try await chat.stream(
            [
                ChatTurn(role: "user", text: "Say A"),
                ChatTurn(role: "assistant", text: "A"),
                ChatTurn(role: "user", text: "Reply with exactly: PONG"),
            ],
            ChatModelCatalog.default.id,
            "medium",
            Preferences.defaultSystemPrompt,
            [],
            .automatic,
            UUID()
        ) {
            if case .outputTextDelta(let delta) = event { text += delta }
        }
        #expect(text.contains("PONG"))
    }

    @Test("Web search runs and the backend reports it")
    func webSearchRuns() async throws {
        let auth = liveAuth()
        try #require(auth.isSignedIn())
        let chat = withDependencies { $0.openAIAuth = auth } operation: { ChatClient.liveValue }

        var searched = false
        var text = ""
        for try await event in try await chat.stream(
            [ChatTurn(role: "user", text: "Search the web for the current Swift release and answer in one line.")],
            ChatModelCatalog.default.id,
            "low",
            "Use the web when the answer depends on current facts.",
            [.webSearch],
            .automatic,
            UUID()
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
        let chat = withDependencies { $0.openAIAuth = auth } operation: { ChatClient.liveValue }

        for option in ChatModelCatalog.all {
            for effort in option.efforts {
                var text = ""
                for try await event in try await chat.stream(
                    [ChatTurn(role: "user", text: "hi")],
                    option.id,
                    effort,
                    "Be terse.",
                    [],
                    .automatic,
                    UUID()
                ) {
                    if case .outputTextDelta(let delta) = event { text += delta }
                }
                #expect(!text.isEmpty, "\(option.id) / \(effort) returned nothing")
            }
        }
    }
}
