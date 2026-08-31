import Foundation

/// Request/response shapes for the Responses API as the Codex backend serves it.
public enum ResponsesAPI {
    public struct Request: Encodable {
        public var model: String
        public var instructions: String
        public var input: [Item]
        public var stream = true
        public var store = false
        public var reasoning: Reasoning?
        public var include: [String] = []

        public init(model: String, instructions: String, input: [Item], reasoning: Reasoning?) {
            self.model = model
            self.instructions = instructions
            self.input = input
            self.reasoning = reasoning
        }
    }

    public struct Reasoning: Encodable {
        public var effort: String
        public var summary = "auto"
        public init(effort: String) { self.effort = effort }
    }

    public struct Item: Encodable {
        public var type = "message"
        public var role: String
        public var content: [Content]

        public init(role: String, text: String) {
            self.role = role
            self.content = [Content(type: role == "assistant" ? "output_text" : "input_text", text: text)]
        }
    }

    public struct Content: Encodable {
        public var type: String
        public var text: String
    }
}

/// The subset of `response.*` stream events Flare renders.
public enum StreamEvent: Sendable, Equatable {
    case outputTextDelta(String)
    case reasoningSummaryDelta(String)
    case completed
    case failed(String)
}

extension StreamEvent {
    /// Decodes one SSE `data:` payload. Unknown event types are ignored.
    static func decode(_ data: Data) -> StreamEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { return nil }

        switch type {
        case "response.output_text.delta":
            return (object["delta"] as? String).map(StreamEvent.outputTextDelta)
        case "response.reasoning_summary_text.delta":
            return (object["delta"] as? String).map(StreamEvent.reasoningSummaryDelta)
        case "response.completed":
            return .completed
        case "response.failed", "error":
            let error = object["error"] as? [String: Any]
                ?? (object["response"] as? [String: Any])?["error"] as? [String: Any]
            return .failed(error?["message"] as? String ?? "The model stopped unexpectedly.")
        default:
            return nil
        }
    }
}
