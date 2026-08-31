import Dependencies
import DependenciesMacros
import Foundation
import os

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
        _ tools: [ResponsesAPI.Tool],
        _ preference: CredentialPreference,
        _ sessionId: UUID
    ) async throws -> AsyncThrowingStream<StreamEvent, Error>
}

public extension ChatClient {
    func complete(
        turns: [ChatTurn],
        model: String,
        instructions: String,
        sessionId: UUID = UUID()
    ) async throws -> String {
        var text = ""
        for try await event in try await stream(turns, model, nil, instructions, [], .automatic, sessionId) {
            if case .outputTextDelta(let delta) = event { text += delta }
        }
        return text
    }
}

extension ChatClient: DependencyKey {
    // A ChatGPT subscription is only honoured by the Codex backend; an API key is
    // only honoured by the public API. The credential decides the endpoint.
    static let codexURL = URL(string: "https://chatgpt.com/backend-api/codex/responses")!
    static let apiURL = URL(string: "https://api.openai.com/v1/responses")!
    static let logger = Logger(subsystem: "ca.optimalapps.flare", category: "chat")

    public static var liveValue: Self {
        @Dependency(\.openAIAuth) var auth

        return Self(
            stream: { turns, model, effort, instructions, tools, preference, sessionId in
                let credentials = try await auth.credentials(preference)

                var request: URLRequest
                switch credentials {
                case .apiKey(let key):
                    request = URLRequest(url: apiURL)
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

                case .chatgpt(let tokens):
                    request = URLRequest(url: codexURL)
                    request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
                    request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
                    request.setValue(sessionId.uuidString, forHTTPHeaderField: "session_id")
                    if let accountId = tokens.accountId ?? tokens.account?.accountId {
                        request.setValue(accountId, forHTTPHeaderField: "chatgpt-account-id")
                    }
                }

                request.httpMethod = "POST"
                request.timeoutInterval = 300
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                let payload = ResponsesAPI.Request(
                    model: model,
                    instructions: instructions,
                    input: turns.map { ResponsesAPI.Item(role: $0.role, text: $0.text) },
                    reasoning: effort.map(ResponsesAPI.Reasoning.init(effort:)),
                    tools: tools
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
                    for try await line in bytes.lines where body.count < 2000 { body += line }
                    let shown = String(body.prefix(200))
                    logger.error(
                        """
                        \(http.statusCode, privacy: .public) from \(request.url?.host() ?? "?", privacy: .public)
                        request: \(String(decoding: request.httpBody ?? Data(), as: UTF8.self), privacy: .public)
                        response: \(body, privacy: .public)
                        """
                    )
                    throw ChatError.server(http.statusCode, shown)
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

    public static func echo(_ text: String) -> Self {
        Self(stream: { _, _, _, _, _, _, _ in
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
