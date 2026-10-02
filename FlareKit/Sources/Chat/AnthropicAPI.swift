import Foundation

/// The Messages API. Haiku and the models before 4.6 think within a token budget;
/// later ones think adaptively at an effort.
public enum AnthropicAPI {
    public static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let modelsURL = URL(string: "https://api.anthropic.com/v1/models?limit=1000")!
    public static let version = "2023-06-01"

    public struct Request: Encodable {
        public var model: String
        public var maxTokens: Int
        public var system: String
        public var messages: [Message]
        public var stream = true
        public var thinking: Thinking?
        public var outputConfig: OutputConfig?
        public var fallbacks: String?
        public var tools: [Tool]

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case system
            case messages
            case stream
            case thinking
            case outputConfig = "output_config"
            case fallbacks
            case tools
        }

        public init(model: String, effort: String?, instructions: String, turns: [ChatTurn], webSearch: Bool) {
            self.model = model
            let claude = ClaudeModel(model)
            switch claude?.thinking ?? .alwaysOn {
            case .budget:
                let budget = AnthropicAPI.budget(for: effort)
                thinking = budget.map { Thinking(type: "enabled", budgetTokens: $0) }
                maxTokens = 16384 + (budget ?? 0)
            case .adaptive where effort == nil:
                thinking = Thinking(type: "disabled")
                maxTokens = 16384
            case .adaptive, .alwaysOn:
                // 4.6 summarizes by default; later models leave thoughts empty unless asked.
                let summarizes = claude?.isBefore([4, 7]) == true
                thinking = Thinking(type: "adaptive", display: summarizes ? nil : "summarized")
                outputConfig = OutputConfig(effort: effort ?? Effort.low)
                maxTokens = 64000
            }
            fallbacks = claude?.hasDefaultFallback == true ? "default" : nil
            system = instructions
            messages = turns.compactMap(Message.init)
            tools = webSearch ? [Tool()] : []
        }
    }

    public struct Message: Encodable {
        public var role: String
        public var content: [Content]

        /// Nil for a turn with nothing to send: the API rejects an empty message.
        public init?(_ turn: ChatTurn) {
            role = turn.role
            var parts: [Content] = []
            if turn.role != "assistant" {
                for image in turn.images {
                    parts.append(
                        Content(
                            type: "image",
                            source: Source(mediaType: ImageMIME.type(of: image), data: image.base64EncodedString())
                        )
                    )
                }
            }
            // Trailing whitespace on an assistant turn is rejected too.
            let text = turn.role == "assistant" ? turn.text.trimmingCharacters(in: .whitespacesAndNewlines) : turn.text
            if !text.isEmpty { parts.append(Content(type: "text", text: text)) }
            guard !parts.isEmpty else { return nil }
            content = parts
        }
    }

    public struct Content: Encodable {
        public var type: String
        public var text: String?
        public var source: Source?
    }

    public struct Source: Encodable {
        public var type = "base64"
        public var mediaType: String
        public var data: String

        enum CodingKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }
    }

    public struct Thinking: Encodable {
        public var type: String
        public var budgetTokens: Int?
        public var display: String?

        enum CodingKeys: String, CodingKey {
            case type
            case budgetTokens = "budget_tokens"
            case display
        }
    }

    public struct OutputConfig: Encodable {
        public var effort: String
    }

    /// The effort stops a model takes. Off is missing where thinking cannot be turned off.
    public static func efforts(for model: String) -> [String] {
        let claude = ClaudeModel(model)
        switch claude?.thinking ?? .alwaysOn {
        case .budget:
            return Effort.standard
        case .adaptive:
            return Effort.standard + (claude?.isBefore([4, 7]) == true ? [] : [Effort.extraHigh]) + [Effort.max]
        case .alwaysOn:
            return [Effort.low, Effort.medium, Effort.high, Effort.extraHigh, Effort.max]
        }
    }

    public struct Tool: Encodable {
        public var type = "web_search_20250305"
        public var name = "web_search"
        public var maxUses = 5

        enum CodingKeys: String, CodingKey {
            case type
            case name
            case maxUses = "max_uses"
        }
    }

    /// At least 1,024 and below `max_tokens`, as the API requires.
    public static func budget(for effort: String?) -> Int? {
        switch effort {
        case Effort.low: 2048
        case Effort.medium: 8192
        case Effort.high, Effort.extraHigh: 32768
        default: nil
        }
    }

    static func urlRequest(key: String, body: Request) throws -> URLRequest {
        var request = URLRequest(url: messagesURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(version, forHTTPHeaderField: "anthropic-version")
        if body.fallbacks != nil { request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    struct EventDecoder: StreamDecoder {
        private var thinkingBlocks = 0

        mutating func decode(_ payload: Data) -> [StreamEvent] {
            guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  let type = object["type"] as? String
            else { return [] }

            switch type {
            case "content_block_start":
                let block = object["content_block"] as? [String: Any]
                switch block?["type"] as? String {
                case "thinking":
                    thinkingBlocks += 1
                    return thinkingBlocks > 1 ? [.reasoningSummaryDelta("\n\n")] : []
                case "server_tool_use": return [.webSearchStarted]
                case "web_search_tool_result": return [.webSearchFinished]
                default: return []
                }
            case "content_block_delta":
                guard let delta = object["delta"] as? [String: Any] else { return [] }
                switch delta["type"] as? String {
                case "text_delta":
                    return (delta["text"] as? String).map { [.outputTextDelta($0)] } ?? []
                case "thinking_delta":
                    return (delta["thinking"] as? String).map { [.reasoningSummaryDelta($0)] } ?? []
                case "citations_delta":
                    guard let citation = delta["citation"] as? [String: Any],
                          let url = citation["url"] as? String
                    else { return [] }
                    return [.citation(Citation(title: citation["title"] as? String ?? url, url: url))]
                default:
                    return []
                }
            case "message_delta":
                let delta = object["delta"] as? [String: Any]
                return delta?["stop_reason"] as? String == "refusal" ? [.failed("Claude declined to answer this.")] : []
            case "message_stop":
                return [.completed]
            case "error":
                let error = object["error"] as? [String: Any]
                return [.failed(error?["message"] as? String ?? "The model stopped unexpectedly.")]
            default:
                return []
            }
        }
    }
}

public enum ImageMIME {
    public static func type(of data: Data) -> String {
        let head = [UInt8](data.prefix(12))
        if head.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if head.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if head.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
        if head.count >= 12, head[8...11] == [0x57, 0x45, 0x42, 0x50] { return "image/webp" }
        return "image/png"
    }
}

/// A Claude model id read for what it takes: `claude-sonnet-4-5-20250929` is Sonnet 4.5,
/// and the older `claude-3-5-sonnet` form reads as family "3". Nil for an id without a
/// version, which is treated as a current model.
struct ClaudeModel {
    enum Thinking { case budget, adaptive, alwaysOn }

    let family: String
    let version: [Int]

    init?(_ id: String) {
        let parts = ModelInfo(id: id).bareID.lowercased().split(separator: "-")
        guard parts.count > 2, parts[0] == "claude" else { return nil }
        family = String(parts[1])
        version = parts.dropFirst(2).prefix { $0.count < 8 && Int($0) != nil }.compactMap { Int($0) }
        if version.isEmpty, Int(family) == nil { return nil }
    }

    func isBefore(_ release: [Int]) -> Bool {
        Int(family) != nil || version.lexicographicallyPrecedes(release)
    }

    var thinking: Thinking {
        if isBefore([4, 6]) { return .budget }
        if family == "fable" || family == "mythos" || !isBefore([5, 5]) { return .alwaysOn }
        return .adaptive
    }

    /// The models whose safeguards can decline, which Anthropic retries on a model it picks.
    var hasDefaultFallback: Bool {
        switch family {
        case "fable": true
        case "opus": !isBefore([5])
        case "sonnet": !isBefore([5, 5])
        default: false
        }
    }
}
