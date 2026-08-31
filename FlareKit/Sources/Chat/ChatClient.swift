import Dependencies
import DependenciesMacros
import Foundation

public struct ChatTurn: Sendable, Equatable {
    public var role: String
    public var text: String
    public init(role: String, text: String) {
        self.role = role
        self.text = text
    }
}

public enum ChatError: LocalizedError, Equatable {
    case unauthorized
    case rateLimited
    case server(Int, String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Your ChatGPT session expired. Sign in again from Settings."
        case .rateLimited: "You hit the ChatGPT rate limit. Wait a moment and try again."
        case .server(let code, let body): "The Codex backend returned \(code): \(body)"
        }
    }
}

@DependencyClient
public struct ChatClient: Sendable {
    public var stream: @Sendable (
        _ turns: [ChatTurn],
        _ model: String,
        _ effort: String?,
        _ instructions: String,
        _ sessionId: UUID
    ) async throws -> AsyncThrowingStream<StreamEvent, Error>
}

extension ChatClient: DependencyKey {
    /// `chatgpt.com/backend-api/codex` is the endpoint a ChatGPT subscription grants;
    /// `api.openai.com/v1` needs a metered API key instead.
    static let baseURL = URL(string: "https://chatgpt.com/backend-api/codex")!

    public static var liveValue: Self {
        @Dependency(\.openAIAuth) var auth

        return Self(
            stream: { turns, model, effort, instructions, sessionId in
                let tokens = try await auth.validTokens()

                var request = URLRequest(url: baseURL.appending(path: "responses"))
                request.httpMethod = "POST"
                request.timeoutInterval = 300
                request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
                request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
                request.setValue(sessionId.uuidString, forHTTPHeaderField: "session_id")
                if let accountId = tokens.accountId ?? tokens.account?.accountId {
                    request.setValue(accountId, forHTTPHeaderField: "chatgpt-account-id")
                }

                let payload = ResponsesAPI.Request(
                    model: model,
                    instructions: instructions,
                    input: turns.map { ResponsesAPI.Item(role: $0.role, text: $0.text) },
                    reasoning: effort.map(ResponsesAPI.Reasoning.init(effort:))
                )
                request.httpBody = try JSONEncoder().encode(payload)

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw ChatError.server(-1, "no response")
                }
                switch http.statusCode {
                case 200..<300: break
                case 401, 403: throw ChatError.unauthorized
                case 429: throw ChatError.rateLimited
                default:
                    var body = ""
                    for try await line in bytes.lines where body.count < 500 { body += line }
                    throw ChatError.server(http.statusCode, body)
                }

                return AsyncThrowingStream { continuation in
                    let task = Task {
                        var parser = SSEParser()
                        var chunk = Data()
                        do {
                            for try await byte in bytes {
                                chunk.append(byte)
                                guard byte == 0x0A else { continue }
                                let payloads = parser.consume(chunk)
                                chunk.removeAll(keepingCapacity: true)
                                for payload in payloads {
                                    guard let event = StreamEvent.decode(payload) else { continue }
                                    continuation.yield(event)
                                    if case .completed = event { continuation.finish(); return }
                                }
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        )
    }
}

extension ChatClient: TestDependencyKey {
    public static let testValue = Self()

    /// Emits `text` one word at a time so previews and tests exercise the streaming path.
    public static func echo(_ text: String) -> Self {
        Self(stream: { _, _, _, _, _ in
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
