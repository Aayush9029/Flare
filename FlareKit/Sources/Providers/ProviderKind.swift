import Foundation

public enum ProviderKind: String, Codable, Sendable, CaseIterable {
    case chatGPT = "chatgpt"
    case openAI = "openai"
    case anthropic
    case groq
    case gemini
    case openRouter = "openrouter"
    case compatible

    public var title: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .groq: "Groq"
        case .gemini: "Gemini"
        case .openRouter: "OpenRouter"
        case .compatible: "Custom"
        }
    }

    public var symbol: String {
        switch self {
        case .chatGPT: "person.crop.circle"
        case .openAI, .anthropic, .groq, .gemini, .openRouter: "key"
        case .compatible: "server.rack"
        }
    }

    public var icon: String? {
        switch self {
        case .chatGPT, .openAI: "openai"
        case .anthropic: "anthropic"
        case .groq: "groq"
        case .gemini: "gemini"
        case .openRouter: "openrouter"
        case .compatible: nil
        }
    }

    /// Fixed for the vendors that speak Chat Completions; nil for the rest.
    public var baseURL: URL? {
        switch self {
        case .groq: URL(string: "https://api.groq.com/openai/v1")
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")
        case .openRouter: URL(string: "https://openrouter.ai/api/v1")
        case .chatGPT, .openAI, .anthropic, .compatible: nil
        }
    }

    public var description: String {
        switch self {
        case .chatGPT: "Your ChatGPT subscription. GPT-6, web search and images, no extra billing."
        case .openAI: "GPT-6 through the API, billed per token."
        case .anthropic: "Claude Fable, Opus, Sonnet and Haiku, billed per token."
        case .groq: "Open models on Groq's own chips. Very fast."
        case .gemini: "Google's Gemini models. Multimodal, long context."
        case .openRouter: "Hundreds of models from every vendor behind one key."
        case .compatible: "Any server that speaks OpenAI's Chat Completions."
        }
    }

    public var keyPlaceholder: String {
        switch self {
        case .chatGPT: ""
        case .openAI: "sk-proj-xxxx..."
        case .anthropic: "sk-ant-xxxx..."
        case .groq: "gsk_xxxx..."
        case .gemini: "AIza..."
        case .openRouter: "sk-or-v1-xxxx..."
        case .compatible: "Optional"
        }
    }

    public var signupURL: URL? {
        switch self {
        case .chatGPT, .compatible: nil
        case .openAI: URL(string: "https://platform.openai.com/signup")
        case .anthropic: URL(string: "https://console.anthropic.com/signup")
        case .groq: URL(string: "https://console.groq.com/signup")
        case .gemini: URL(string: "https://aistudio.google.com/app/apikey")
        case .openRouter: URL(string: "https://openrouter.ai/settings/keys")
        }
    }

    public static let builtIn: [ProviderKind] = [.chatGPT, .openAI, .anthropic, .groq, .gemini, .openRouter]
}
