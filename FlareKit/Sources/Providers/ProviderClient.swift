import Dependencies
import DependenciesMacros
import Foundation

public enum ProviderError: LocalizedError, Equatable {
    case rejected(String)
    case unreachable(String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .rejected(let name): "\(name) rejected that key."
        case .unreachable(let name): "Could not reach \(name)."
        case .failed(let message): message
        }
    }
}

@DependencyClient
public struct ProviderClient: Sendable {
    /// Lists the models an endpoint serves, which also proves the key.
    public var listModels: @Sendable (_ endpoint: ChatEndpoint, _ apiKey: String) async throws -> [ModelInfo]
}

extension ProviderClient: DependencyKey {
    public static let liveValue = Self(
        listModels: { endpoint, key in
            var request: URLRequest
            let name: String
            switch endpoint {
            case .chatGPT, .openAI:
                return ChatModelCatalog.all.map { ModelInfo(id: $0.id, name: $0.displayName, efforts: $0.efforts) }
            case .anthropic:
                request = URLRequest(url: AnthropicAPI.modelsURL)
                request.setValue(key, forHTTPHeaderField: "x-api-key")
                request.setValue(AnthropicAPI.version, forHTTPHeaderField: "anthropic-version")
                name = "Anthropic"
            case .compatible(let baseURL, _):
                request = URLRequest(url: baseURL.appending(path: "models"))
                if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
                name = baseURL.host() ?? "the server"
            }
            request.timeoutInterval = 20

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw ProviderError.unreachable(name)
            }
            guard let http = response as? HTTPURLResponse else { throw ProviderError.unreachable(name) }
            switch http.statusCode {
            case 200..<300: break
            case 401, 403: throw ProviderError.rejected(name)
            default:
                let body = String(decoding: data, as: UTF8.self)
                throw ProviderError.failed(StreamingHTTP.message(in: body) ?? "\(name) returned \(http.statusCode).")
            }
            return ModelListing.parse(data, host: request.url?.host())
                .filter(ModelListing.isChatModel)
        }
    )
}

extension ProviderClient: TestDependencyKey {
    public static let testValue = Self()

    public static func listing(_ models: [ModelInfo]) -> Self {
        Self(listModels: { _, _ in models })
    }
}

public extension DependencyValues {
    var providerClient: ProviderClient {
        get { self[ProviderClient.self] }
        set { self[ProviderClient.self] = newValue }
    }
}

/// Reads a `/models` answer in any of its dialects: OpenAI's `data` array, a bare
/// array, Anthropic's `display_name`, OpenRouter's `supported_parameters` and
/// `context_length`, Groq's `context_window`.
public enum ModelListing {
    public static func parse(_ data: Data, host: String? = nil) -> [ModelInfo] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let entries = (json as? [String: Any]).flatMap { $0["data"] as? [[String: Any]] ?? $0["models"] as? [[String: Any]] }
            ?? json as? [[String: Any]]
            ?? []
        return entries.compactMap { entry in
            guard let id = entry["id"] as? String ?? entry["name"] as? String, !id.isEmpty else { return nil }
            if !speaksText(entry) { return nil }
            let name = entry["name"] as? String ?? entry["display_name"] as? String
            let efforts = (entry["supported_parameters"] as? [String]).map { parameters in
                parameters.contains("reasoning") || parameters.contains("reasoning_effort")
                    ? [Effort.low, Effort.medium, Effort.high]
                    : []
            }
            let context = entry["context_length"] as? Int ?? entry["context_window"] as? Int ?? entry["max_context_length"] as? Int
            return ModelInfo(
                id: id,
                name: name,
                efforts: efforts ?? ProviderHints.efforts(host: host, modelID: id),
                context: context
            )
        }
    }

    /// Listings that say what a model takes and gives: text in and text out, or it is
    /// not a chat model.
    private static func speaksText(_ entry: [String: Any]) -> Bool {
        let architecture = entry["architecture"] as? [String: Any]
        let inputs = architecture?["input_modalities"] as? [String] ?? entry["input_modalities"] as? [String]
        let outputs = architecture?["output_modalities"] as? [String] ?? entry["output_modalities"] as? [String]
        if let inputs, !inputs.contains("text") { return false }
        if let outputs, !outputs.contains("text") { return false }
        return true
    }

    /// Listings that say nothing are sifted by name: speech, embeddings, guards,
    /// image and video models are not chat models.
    public static func isChatModel(_ model: ModelInfo) -> Bool {
        let id = model.id.lowercased()
        let excluded = [
            "whisper", "tts", "embed", "guard", "moderation", "imagen", "veo", "-image", "image-", "video",
            "orpheus", "aqa", "audio", "realtime", "transcri", "dall-e", "rerank", "sora", "computer-use",
            "learnlm", "gemini-embedding", "-live", "native-audio",
        ]
        return !excluded.contains { id.contains($0) }
    }
}
