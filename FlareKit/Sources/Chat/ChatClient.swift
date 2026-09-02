import Dependencies
import DependenciesMacros
import Foundation

public struct ChatTurn: Sendable, Equatable {
    public var role: String
    public var text: String
    /// Encoded image files a user turn carries.
    public var images: [Data]
    public init(role: String, text: String, images: [Data] = []) {
        self.role = role
        self.text = text
        self.images = images
    }
}

public enum ChatError: LocalizedError, Equatable {
    case unauthorized(String)
    case rateLimited(String)
    case missingCredential(String)
    case server(String, Int, String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized("ChatGPT"): "Your ChatGPT session expired. Sign in again from Settings."
        case .unauthorized(let name): "\(name) rejected the key. Check it in Settings."
        case .rateLimited(let name): "\(name) is rate limiting you. Wait a moment and try again."
        case .missingCredential(let name): "Add a key for \(name) in Settings."
        case .server(let name, let code, let body): "\(name) returned \(code): \(body)"
        }
    }
}

@DependencyClient
public struct ChatClient: Sendable {
    public var stream: @Sendable (ChatRequest) async throws -> AsyncThrowingStream<StreamEvent, Error>
}

public extension ChatClient {
    func complete(_ request: ChatRequest) async throws -> String {
        var text = ""
        for try await event in try await stream(request) {
            if case .outputTextDelta(let delta) = event { text += delta }
        }
        return text
    }
}

extension ChatClient: DependencyKey {
    // A ChatGPT subscription is only honoured by the Codex backend; an API key is
    // only honoured by the public API. The endpoint follows the credential.
    static let codexURL = URL(string: "https://chatgpt.com/backend-api/codex/responses")!
    static let apiURL = URL(string: "https://api.openai.com/v1/responses")!

    public static var liveValue: Self {
        @Dependency(\.openAIAuth) var auth
        @Dependency(\.apiKeyStore) var keys
        @Dependency(\.providerStore) var providers

        return Self(
            stream: { chat in
                let request: URLRequest
                let name: String
                switch chat.endpoint {
                case .chatGPT:
                    name = "ChatGPT"
                    let tokens = try await auth.validTokens()
                    var codex = URLRequest(url: codexURL)
                    codex.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
                    codex.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
                    codex.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
                    codex.setValue(chat.sessionID.uuidString, forHTTPHeaderField: "session_id")
                    if let accountId = tokens.accountId ?? tokens.account?.accountId {
                        codex.setValue(accountId, forHTTPHeaderField: "chatgpt-account-id")
                    }
                    request = try ResponsesAPI.fill(codex, with: chat)

                case .openAI:
                    name = "OpenAI"
                    guard let key = keys.load() else { throw ChatError.missingCredential(name) }
                    var api = URLRequest(url: apiURL)
                    api.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    request = try ResponsesAPI.fill(api, with: chat)

                case .anthropic:
                    name = "Claude"
                    guard let key = providers.load().key(for: ProviderKind.anthropic.rawValue) else {
                        throw ChatError.missingCredential(name)
                    }
                    request = try AnthropicAPI.urlRequest(
                        key: key,
                        body: AnthropicAPI.Request(
                            model: chat.model,
                            effort: chat.effort,
                            instructions: chat.instructions,
                            turns: chat.turns,
                            webSearch: chat.webSearch
                        )
                    )

                case .compatible(let baseURL, let id):
                    let file = providers.load()
                    name = ProviderKind(rawValue: id)?.title
                        ?? file.custom.first { $0.id.uuidString == id }?.name
                        ?? baseURL.host()
                        ?? "The server"
                    let isOpenRouter = chat.endpoint.isOpenRouter
                    request = try ChatCompletionsAPI.urlRequest(
                        baseURL: baseURL,
                        key: file.key(for: id) ?? "",
                        body: ChatCompletionsAPI.Request(
                            model: chat.model,
                            effort: chat.effort,
                            instructions: chat.instructions,
                            turns: chat.turns,
                            isOpenRouter: isOpenRouter
                        ),
                        isOpenRouter: isOpenRouter
                    )
                }

                let bytes = try await StreamingHTTP.open(request, provider: name)
                switch chat.endpoint {
                case .chatGPT, .openAI:
                    return StreamingHTTP.events(from: bytes, decoder: ResponsesAPI.EventDecoder())
                case .anthropic:
                    return StreamingHTTP.events(from: bytes, decoder: AnthropicAPI.EventDecoder())
                case .compatible:
                    return StreamingHTTP.events(from: bytes, decoder: ChatCompletionsAPI.EventDecoder())
                }
            }
        )
    }
}

extension ChatClient: TestDependencyKey {
    public static let testValue = Self()

    public static func echo(_ text: String) -> Self {
        Self(stream: { _ in
            AsyncThrowingStream { continuation in
                Task {
                    for word in text.split(separator: " ", omittingEmptySubsequences: false) {
                        try? await Task.sleep(for: .milliseconds(35))
                        continuation.yield(.outputTextDelta(word + " "))
                    }
                    continuation.yield(.completed)
                    continuation.finish()
                }
            }
        })
    }
}

public extension DependencyValues {
    var chatClient: ChatClient {
        get { self[ChatClient.self] }
        set { self[ChatClient.self] = newValue }
    }
}
