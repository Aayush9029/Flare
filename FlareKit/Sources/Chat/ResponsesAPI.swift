import Foundation

public enum ResponsesAPI {
    public struct Request: Encodable {
        public var model: String
        public var instructions: String
        public var input: [Item]
        public var stream = true
        public var store = false
        public var reasoning: Reasoning?
        public var include: [String] = []
        public var tools: [Tool] = []

        public init(
            model: String,
            instructions: String,
            input: [Item],
            reasoning: Reasoning?,
            tools: [Tool] = []
        ) {
            self.model = model
            self.instructions = instructions
            self.input = input
            self.reasoning = reasoning
            self.tools = tools
        }
    }

    /// The Codex backend accepts `web_search` and `image_generation`; it rejects
    /// `code_interpreter`, `file_search` and `computer_use_preview`.
    public struct Tool: Encodable, Equatable, Sendable {
        public var type: String
        public var size: String?
        public var quality: String?

        public init(type: String, size: String? = nil, quality: String? = nil) {
            self.type = type
            self.size = size
            self.quality = quality
        }

        public static let webSearch = Tool(type: "web_search")
        public static let imageGeneration = Tool(
            type: "image_generation",
            size: "1024x1024",
            quality: "low"
        )
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

        public init(role: String, text: String, images: [Data] = []) {
            self.role = role
            var parts: [Content] = []
            if !text.isEmpty || images.isEmpty {
                parts.append(Content(type: role == "assistant" ? "output_text" : "input_text", text: text))
            }
            if role != "assistant" {
                for image in images {
                    parts.append(Content(type: "input_image", imageURL: "data:\(Self.mimeType(of: image));base64,\(image.base64EncodedString())"))
                }
            }
            self.content = parts
        }

        static func mimeType(of data: Data) -> String {
            let head = [UInt8](data.prefix(12))
            if head.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
            if head.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
            if head.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
            if head.count >= 12, head[8...11] == [0x57, 0x45, 0x42, 0x50] { return "image/webp" }
            return "image/png"
        }
    }

    public struct Content: Encodable {
        public var type: String
        public var text: String?
        public var imageURL: String?

        public init(type: String, text: String? = nil, imageURL: String? = nil) {
            self.type = type
            self.text = text
            self.imageURL = imageURL
        }

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }
    }
}

public enum StreamEvent: Sendable, Equatable {
    case outputTextDelta(String)
    case reasoningSummaryDelta(String)
    case webSearchStarted
    case webSearchFinished
    case imageGenerationStarted
    case image(Data)
    case citation(Citation)
    case completed
    case failed(String)
}

public struct Citation: Sendable, Equatable, Hashable, Identifiable {
    public var title: String
    public var url: String

    public var id: String { url }

    public var host: String {
        URL(string: url)?.host()?.replacingOccurrences(of: "www.", with: "") ?? url
    }
}

extension StreamEvent {
    static func decode(_ data: Data) -> StreamEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { return nil }

        switch type {
        case "response.output_text.delta":
            return (object["delta"] as? String).map(StreamEvent.outputTextDelta)
        case "response.reasoning_summary_text.delta":
            return (object["delta"] as? String).map(StreamEvent.reasoningSummaryDelta)
        case "response.reasoning_summary_part.added":
            // Parts arrive as separate paragraphs with no separator of their own.
            guard let index = object["summary_index"] as? Int, index > 0 else { return nil }
            return .reasoningSummaryDelta("\n\n")
        case "response.web_search_call.in_progress", "response.web_search_call.searching":
            return .webSearchStarted
        case "response.web_search_call.completed":
            return .webSearchFinished
        case "response.image_generation_call.in_progress",
             "response.image_generation_call.generating":
            return .imageGenerationStarted
        case "response.output_item.done":
            guard let item = object["item"] as? [String: Any],
                  item["type"] as? String == "image_generation_call",
                  let base64 = item["result"] as? String,
                  let data = Data(base64Encoded: base64)
            else { return nil }
            return .image(data)
        case "response.output_text.annotation.added":
            // Shape varies by backend, so read it defensively rather than decoding.
            let annotation = object["annotation"] as? [String: Any] ?? object
            guard annotation["type"] as? String == "url_citation",
                  let url = annotation["url"] as? String
            else { return nil }
            return .citation(
                Citation(title: annotation["title"] as? String ?? url, url: url)
            )
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
