import Dependencies
import Foundation
import Testing

@testable import FlareKit

@Suite(
    "Live chat",
    .enabled(if: ProcessInfo.processInfo.environment["FLARE_LIVE_TESTS"] != nil)
)
struct LiveChatTests {
    private func signedInDependencies() throws -> (OpenAIAuthClient, ChatClient) {
        let store = TokenStore.ephemeral()
        let auth = withDependencies {
            $0.tokenStore = store
            $0.apiKeyStore = .ephemeral()
        } operation: {
            OpenAIAuthClient.liveValue
        }
        let chat = withDependencies {
            $0.openAIAuth = auth
            $0.apiKeyStore = .ephemeral()
            $0.providerStore = .ephemeral()
        } operation: {
            ChatClient.liveValue
        }
        return (auth, chat)
    }

    @Test("Imports the Codex CLI session")
    func importSession() async throws {
        let (auth, _) = try signedInDependencies()
        let tokens = try await auth.importFromCodexCLI()

        #expect(!tokens.accessToken.isEmpty)
        #expect(tokens.account?.accountId != nil)
        #expect(auth.isSignedIn())
    }

    @Test("Streams a completion from the Codex backend")
    func streamsCompletion() async throws {
        let (auth, chat) = try signedInDependencies()
        _ = try await auth.importFromCodexCLI()

        let events = try await chat.stream(
            ChatRequest(
                endpoint: .chatGPT,
                model: "gpt-5.6-terra",
                effort: nil,
                instructions: "Be terse.",
                turns: [ChatTurn(role: "user", text: "Reply with exactly the word PONG and nothing else.")]
            )
        )

        var text = ""
        var didComplete = false
        for try await event in events {
            switch event {
            case .outputTextDelta(let delta): text += delta
            case .completed: didComplete = true
            case .failed(let message): Issue.record("stream failed: \(message)")
            default: break
            }
        }

        #expect(didComplete)
        #expect(text.contains("PONG"))
    }
}
