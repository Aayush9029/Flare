import Foundation

/// Where a request goes. The credential is looked up at send time, so no key
/// travels through the UI.
public enum ChatEndpoint: Hashable, Sendable {
    case chatGPT
    case openAI
    case anthropic
    /// Chat Completions at `baseURL`; `providerID` names the key and the listed models.
    case compatible(baseURL: URL, providerID: String)

    public var kind: ProviderKind {
        switch self {
        case .chatGPT: .chatGPT
        case .openAI: .openAI
        case .anthropic: .anthropic
        case .compatible(_, let id): ProviderKind(rawValue: id) ?? .compatible
        }
    }

    public var isOpenRouter: Bool {
        if case .compatible(let baseURL, _) = self { return baseURL.host()?.hasSuffix("openrouter.ai") == true }
        return false
    }
}
