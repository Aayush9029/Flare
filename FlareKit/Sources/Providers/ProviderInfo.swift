import Foundation

/// A provider as the UI sees it: what it is called, whether it can answer, and
/// which models it lists.
public struct ProviderInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: ProviderKind
    public let name: String
    public let isReady: Bool
    public let caption: String
    public let models: [ModelInfo]
    public let endpoint: ChatEndpoint

    public init(
        id: String,
        kind: ProviderKind,
        name: String,
        isReady: Bool,
        caption: String,
        models: [ModelInfo],
        endpoint: ChatEndpoint
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.isReady = isReady
        self.caption = caption
        self.models = models
        self.endpoint = endpoint
    }

    public var baseURL: URL? {
        if case .compatible(let url, _) = endpoint { return url }
        return nil
    }

    /// The bundled brand mark, or nil when only the kind's symbol fits.
    public var icon: String? {
        if kind == .compatible, let baseURL { return ProviderIcon.name(for: baseURL) }
        return kind.icon
    }

    public var description: String {
        guard kind == .compatible, let baseURL else { return kind.description }
        return baseURL.absoluteString
    }

    public var usesKey: Bool { kind != .chatGPT }
    public var supportsWebSearch: Bool { [.chatGPT, .openAI, .anthropic].contains(kind) }
    public var supportsImageGeneration: Bool { kind == .chatGPT || kind == .openAI }

    /// Long lists get a search and groups; short ones a grid of cards.
    public var isLongList: Bool { models.count > 12 }

    public var defaultSelection: ModelSelection {
        switch kind {
        case .chatGPT, .openAI:
            ModelSelection(model: ChatModelCatalog.default.id, effort: Effort.medium)
        case .anthropic:
            ModelSelection(model: firstModel(prefixed: "claude-sonnet-5") ?? "claude-sonnet-5", effort: nil)
        case .groq:
            ModelSelection(model: firstModel(prefixed: "openai/gpt-oss-120b") ?? models.first?.id ?? "", effort: nil)
        case .gemini:
            ModelSelection(model: firstModel(containing: "gemini-2.5-flash") ?? models.first?.id ?? "", effort: nil)
        case .openRouter:
            ModelSelection(model: firstModel(prefixed: "openai/gpt-oss-120b") ?? models.first?.id ?? "", effort: nil)
        case .compatible:
            ModelSelection(model: models.first?.id ?? "", effort: nil)
        }
    }

    /// The effort stops a model offers. OpenAI's models always reason, so Off is not
    /// among theirs; Claude takes a thinking budget on every model; a listed model of
    /// unknown ability gets the standard set, and Off sends nothing.
    public func efforts(for model: String) -> [String] {
        switch kind {
        case .chatGPT, .openAI:
            return ChatModelCatalog.all.first { $0.id == model }?.efforts ?? [Effort.low, Effort.medium, Effort.high]
        case .anthropic:
            return Effort.standard
        case .groq, .gemini, .openRouter, .compatible:
            guard let info = models.first(where: { $0.id == model }) else { return Effort.standard }
            switch info.efforts {
            case nil: return Effort.standard
            case []?: return []
            case let known?: return [Effort.none] + known.filter { $0 != Effort.none }
            }
        }
    }

    public func clamp(_ selection: ModelSelection) -> ModelSelection {
        guard !selection.model.isEmpty else { return defaultSelection }
        var selection = selection
        let efforts = efforts(for: selection.model)
        switch kind {
        case .chatGPT, .openAI:
            if !efforts.contains(selection.effort ?? "") {
                selection.effort = efforts.contains(Effort.medium) ? Effort.medium : efforts.first
            }
        default:
            if let effort = selection.effort, !efforts.contains(effort) { selection.effort = nil }
        }
        return selection
    }

    public func modelName(_ id: String) -> String {
        models.first { $0.id == id }?.shortName ?? ModelInfo(id: id).shortName
    }

    /// "5.6 Terra · High", or the model alone when nothing is sent for reasoning.
    public func title(for selection: ModelSelection) -> String {
        let name = modelName(selection.model)
        guard let effort = selection.effort else { return name }
        return "\(name) · \(Effort.title(effort))"
    }

    /// The cheapest pairing for a title: one short line, no reasoning.
    public func titleSelection(current: ModelSelection) -> ModelSelection {
        switch kind {
        case .chatGPT, .openAI:
            ModelSelection(model: ChatModelCatalog.titleModel.id, effort: Effort.low)
        case .anthropic:
            ModelSelection(model: firstModel(prefixed: "claude-haiku") ?? current.model, effort: nil)
        case .groq:
            ModelSelection(model: firstModel(containing: "8b-instant") ?? current.model, effort: nil)
        case .gemini:
            ModelSelection(model: firstModel(containing: "flash-lite") ?? current.model, effort: nil)
        case .openRouter, .compatible:
            ModelSelection(model: current.model, effort: nil)
        }
    }

    public var setupMessage: String {
        switch kind {
        case .chatGPT: "Sign in with ChatGPT in Settings to start a chat."
        case .compatible: "Add an endpoint in Settings to start a chat."
        default: "Add a \(name) API key in Settings to start a chat."
        }
    }

    private func firstModel(prefixed prefix: String) -> String? {
        if models.contains(where: { $0.id == prefix }) { return prefix }
        return models.first { $0.id.hasPrefix(prefix) }?.id
    }

    private func firstModel(containing text: String) -> String? {
        models.first { $0.id.contains(text) }?.id
    }
}
