import Foundation

/// Chat Completions, the dialect every OpenAI-compatible server speaks: OpenRouter,
/// Ollama, LM Studio, llama.cpp, vLLM.
public enum ChatCompletionsAPI {
    public struct Request: Encodable {
        public var model: String
        public var messages: [Message]
        public var stream = true
        public var reasoningEffort: String?
        public var reasoning: Reasoning?

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case stream
            case reasoningEffort = "reasoning_effort"
            case reasoning
        }

        /// OpenRouter takes the effort in a `reasoning` object; everyone else takes
        /// OpenAI's `reasoning_effort`. Off sends neither.
        public init(model: String, effort: String?, instructions: String, turns: [ChatTurn], isOpenRouter: Bool) {
            self.model = model
            var messages: [Message] = []
            if !instructions.isEmpty { messages.append(Message(role: "system", content: .text(instructions))) }
            messages += turns.map(Message.init)
            self.messages = messages
            if let effort, effort != Effort.none {
                if isOpenRouter {
                    reasoning = Reasoning(effort: effort)
                } else {
                    reasoningEffort = effort
                }
            }
        }
    }

    public struct Message: Encodable {
        public var role: String
        public var content: Content

        public init(role: String, content: Content) {
            self.role = role
            self.content = content
        }

        /// Plain text stays a string: a server without vision chokes on parts.
        public init(_ turn: ChatTurn) {
            role = turn.role
            guard turn.role != "assistant", !turn.images.isEmpty else {
                content = .text(turn.text)
                return
            }
            var parts: [Part] = []
            if !turn.text.isEmpty { parts.append(Part(type: "text", text: turn.text)) }
            for image in turn.images {
                let url = "data:\(ImageMIME.type(of: image));base64,\(image.base64EncodedString())"
                parts.append(Part(type: "image_url", imageURL: ImageURL(url: url)))
            }
            content = .parts(parts)
        }
    }

    public enum Content: Encodable {
        case text(String)
        case parts([Part])

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text): try container.encode(text)
            case .parts(let parts): try container.encode(parts)
            }
        }
    }

    public struct Part: Encodable {
        public var type: String
        public var text: String?
        public var imageURL: ImageURL?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }
    }

    public struct ImageURL: Encodable {
        public var url: String
    }

    public struct Reasoning: Encodable {
        public var effort: String
    }

    static func urlRequest(baseURL: URL, key: String, body: Request, isOpenRouter: Bool) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        if isOpenRouter {
            request.setValue("Flare", forHTTPHeaderField: "X-Title")
            request.setValue("https://github.com/Aayush9029/Flare", forHTTPHeaderField: "HTTP-Referer")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    struct EventDecoder: StreamDecoder {
        private var splitter = ThinkTagSplitter()

        mutating func decode(_ payload: Data) -> [StreamEvent] {
            guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { return [] }
            if let error = object["error"] as? [String: Any] {
                return [.failed(error["message"] as? String ?? "The model stopped unexpectedly.")]
            }
            guard let choice = (object["choices"] as? [[String: Any]])?.first,
                  let delta = choice["delta"] as? [String: Any]
            else { return [] }

            var events: [StreamEvent] = []
            // OpenRouter calls it `reasoning`; DeepSeek, vLLM and llama.cpp call it `reasoning_content`.
            if let reasoning = delta["reasoning"] as? String ?? delta["reasoning_content"] as? String, !reasoning.isEmpty {
                events.append(.reasoningSummaryDelta(reasoning))
            }
            if let content = delta["content"] as? String, !content.isEmpty {
                events += splitter.feed(content)
            }
            return events
        }

        mutating func finish() -> [StreamEvent] {
            splitter.flush()
        }
    }
}

/// Splits `<think>…</think>` out of answer text, however the tags fall across chunks.
/// Only an opening tag before any answer text counts, so a model that writes about
/// think tags is not cut short.
struct ThinkTagSplitter: Sendable {
    private var pending = ""
    private var isThinking = false
    private var trimsAnswer = false
    private var answerStarted = false

    mutating func feed(_ text: String) -> [StreamEvent] {
        pending += text
        var events: [StreamEvent] = []
        while true {
            if answerStarted, !isThinking {
                emit(pending, into: &events)
                pending = ""
                return events
            }
            let tag = isThinking ? "</think>" : "<think>"
            if let range = pending.range(of: tag) {
                emit(String(pending[..<range.lowerBound]), into: &events)
                pending = String(pending[range.upperBound...])
                isThinking.toggle()
                trimsAnswer = !isThinking
                continue
            }
            let held = Self.partialTagLength(of: pending, tag: tag)
            let cut = pending.index(pending.endIndex, offsetBy: -held)
            emit(String(pending[..<cut]), into: &events)
            pending = String(pending[cut...])
            return events
        }
    }

    mutating func flush() -> [StreamEvent] {
        var events: [StreamEvent] = []
        emit(pending, into: &events)
        pending = ""
        return events
    }

    private mutating func emit(_ text: String, into events: inout [StreamEvent]) {
        var text = text
        if trimsAnswer, !isThinking {
            let trimmed = text.drop(while: \.isWhitespace)
            guard !trimmed.isEmpty else { return }
            text = String(trimmed)
            trimsAnswer = false
        }
        guard !text.isEmpty else { return }
        if !isThinking, text.contains(where: { !$0.isWhitespace }) { answerStarted = true }
        events.append(isThinking ? .reasoningSummaryDelta(text) : .outputTextDelta(text))
    }

    /// How many trailing characters could still turn into `tag`.
    private static func partialTagLength(of text: String, tag: String) -> Int {
        let longest = min(text.count, tag.count - 1)
        guard longest > 0 else { return 0 }
        for length in stride(from: longest, through: 1, by: -1) where tag.hasPrefix(text.suffix(length)) {
            return length
        }
        return 0
    }
}
