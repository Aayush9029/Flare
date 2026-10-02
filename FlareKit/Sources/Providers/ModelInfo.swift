import Foundation

/// A model an endpoint lists. `efforts` is empty when the model takes no reasoning
/// parameter and nil when the endpoint did not say. `context` is in tokens.
public struct ModelInfo: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var efforts: [String]?
    public var context: Int?

    public init(id: String, name: String? = nil, efforts: [String]? = nil, context: Int? = nil) {
        self.id = id
        self.name = name?.isEmpty == false ? name! : id
        self.efforts = efforts
        self.context = context
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        efforts = try container.decodeIfPresent([String].self, forKey: .efforts)
        context = try container.decodeIfPresent(Int.self, forKey: .context)
    }

    /// The id without a vendor or `models/` prefix.
    public var bareID: String {
        let trimmed = id.hasPrefix("models/") ? String(id.dropFirst(7)) : id
        return trimmed.split(separator: "/").last.map(String.init) ?? trimmed
    }

    /// The name without a vendor prefix, as OpenRouter and Gemini ids carry one.
    public var shortName: String {
        let base = name == id ? bareID : name
        return base.replacingOccurrences(of: "GPT-", with: "")
    }

    /// What a long list groups by: the vendor before the slash, else the family before the first dash.
    public var groupKey: String {
        let trimmed = id.hasPrefix("models/") ? String(id.dropFirst(7)) : id
        if let slash = trimmed.firstIndex(of: "/") { return String(trimmed[..<slash]) }
        return trimmed.split(separator: "-").first.map(String.init) ?? trimmed
    }

    public var groupTitle: String {
        groupKey
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// "128K" or "1M", for the card.
    public var contextLabel: String? {
        guard let context, context > 0 else { return nil }
        if context >= 1_000_000 { return "\(context / 1_000_000)M" }
        return "\(context / 1000)K"
    }

    public var metrics: ModelMetrics? { ModelMetadata.metrics(for: id) }
}

public struct ModelMetrics: Hashable, Sendable {
    public let speed: Int
    public let intelligence: Int
    public let context: Int?

    public init(speed: Int, intelligence: Int, context: Int? = nil) {
        self.speed = speed
        self.intelligence = intelligence
        self.context = context
    }
}

/// Speed and intelligence on a five-point scale for the models people pick most,
/// keyed by the tail of the id so vendor prefixes and date suffixes do not matter.
public enum ModelMetadata {
    private static let table: [(match: String, metrics: ModelMetrics)] = [
        ("gpt-6-astra", ModelMetrics(speed: 1, intelligence: 5, context: 1_050_000)),
        ("gpt-6.1-sol", ModelMetrics(speed: 3, intelligence: 5, context: 1_050_000)),
        ("gpt-6-sol", ModelMetrics(speed: 3, intelligence: 4, context: 1_050_000)),
        ("gpt-6-luna", ModelMetrics(speed: 5, intelligence: 3, context: 1_050_000)),
        ("gpt-5.6-sol", ModelMetrics(speed: 2, intelligence: 5, context: 1_000_000)),
        ("gpt-5.6-terra", ModelMetrics(speed: 3, intelligence: 4, context: 400_000)),
        ("gpt-5.6-luna", ModelMetrics(speed: 5, intelligence: 2, context: 400_000)),
        ("gpt-5.5", ModelMetrics(speed: 2, intelligence: 5, context: 400_000)),
        ("gpt-5.4-mini", ModelMetrics(speed: 3, intelligence: 3, context: 400_000)),
        ("gpt-5.4-nano", ModelMetrics(speed: 4, intelligence: 2, context: 400_000)),
        ("gpt-5.4", ModelMetrics(speed: 2, intelligence: 4, context: 400_000)),
        ("gpt-oss-120b", ModelMetrics(speed: 4, intelligence: 4, context: 128_000)),
        ("gpt-oss-20b", ModelMetrics(speed: 5, intelligence: 3, context: 128_000)),
        ("claude-fable-5", ModelMetrics(speed: 1, intelligence: 5, context: 1_000_000)),
        ("claude-opus-5", ModelMetrics(speed: 2, intelligence: 5, context: 1_000_000)),
        ("claude-sonnet-5", ModelMetrics(speed: 3, intelligence: 4, context: 1_000_000)),
        ("claude-opus-4", ModelMetrics(speed: 1, intelligence: 5, context: 200_000)),
        ("claude-sonnet-4", ModelMetrics(speed: 2, intelligence: 4, context: 200_000)),
        ("claude-haiku-4", ModelMetrics(speed: 4, intelligence: 3, context: 200_000)),
        ("llama-3.3-70b", ModelMetrics(speed: 5, intelligence: 4, context: 128_000)),
        ("llama-3.1-8b", ModelMetrics(speed: 5, intelligence: 2, context: 128_000)),
        ("gemini-3.8-flash", ModelMetrics(speed: 4, intelligence: 4, context: 1_000_000)),
        ("gemini-3.7-flash", ModelMetrics(speed: 4, intelligence: 4, context: 1_000_000)),
        ("gemini-3.6-flash", ModelMetrics(speed: 4, intelligence: 4, context: 1_000_000)),
        ("gemini-3.5-flash-lite", ModelMetrics(speed: 5, intelligence: 3, context: 1_000_000)),
        ("gemini-3.1-pro", ModelMetrics(speed: 2, intelligence: 5, context: 1_000_000)),
        ("gemini-3.1-flash-lite", ModelMetrics(speed: 5, intelligence: 2, context: 1_000_000)),
        ("gemini-3-pro", ModelMetrics(speed: 2, intelligence: 5, context: 1_000_000)),
        ("gemini-3-flash", ModelMetrics(speed: 4, intelligence: 4, context: 1_000_000)),
        ("gemini-3.5-flash", ModelMetrics(speed: 4, intelligence: 4, context: 1_000_000)),
        ("gemini-2.5-pro", ModelMetrics(speed: 2, intelligence: 4, context: 1_000_000)),
        ("gemini-2.5-flash-lite", ModelMetrics(speed: 5, intelligence: 2, context: 1_000_000)),
        ("gemini-2.5-flash", ModelMetrics(speed: 4, intelligence: 3, context: 1_000_000)),
        ("deepseek-r1", ModelMetrics(speed: 2, intelligence: 4, context: 128_000)),
        ("deepseek-chat", ModelMetrics(speed: 3, intelligence: 4, context: 128_000)),
        ("qwen3", ModelMetrics(speed: 4, intelligence: 3, context: 128_000)),
        ("grok-4", ModelMetrics(speed: 2, intelligence: 4, context: 256_000)),
        ("grok-3-mini", ModelMetrics(speed: 4, intelligence: 3, context: 128_000)),
        ("mistral-large", ModelMetrics(speed: 2, intelligence: 4, context: 128_000)),
        ("mistral-small", ModelMetrics(speed: 4, intelligence: 3, context: 128_000)),
        ("mistral-medium", ModelMetrics(speed: 3, intelligence: 3, context: 128_000)),
    ]

    public static func metrics(for id: String) -> ModelMetrics? {
        let bare = ModelInfo(id: id).bareID.lowercased()
        return table.first { bare.hasPrefix($0.match) }?.metrics
    }
}
