import Foundation

/// An OpenAI-compatible endpoint the user added: a local server, or a vendor with no
/// card of its own. Its key and models live in the provider file under its id.
public struct CustomProvider: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var baseURL: URL

    public init(id: UUID, name: String, baseURL: URL) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
    }

    /// Trims whitespace and a trailing slash; adds the scheme people leave out.
    public static func normalize(_ text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "http://" + trimmed }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed), url.host() != nil else { return nil }
        return url
    }

    public struct Preset: Identifiable, Sendable {
        public let name: String
        public let url: String
        public var id: String { name }
    }

    public static let presets = [
        Preset(name: "Ollama", url: "http://localhost:11434/v1"),
        Preset(name: "LM Studio", url: "http://localhost:1234/v1"),
        Preset(name: "llama.cpp", url: "http://localhost:8080/v1"),
        Preset(name: "Mistral", url: "https://api.mistral.ai/v1"),
        Preset(name: "xAI", url: "https://api.x.ai/v1"),
    ]
}
