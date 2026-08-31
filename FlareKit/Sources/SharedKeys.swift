import Sharing

public extension SharedReaderKey where Self == AppStorageKey<String>.Default {
    static var selectedModel: Self {
        Self[.appStorage("selectedModel"), default: ChatModelCatalog.default.id]
    }

    static var reasoningEffort: Self {
        Self[.appStorage("reasoningEffort"), default: "medium"]
    }

    static var systemPrompt: Self {
        Self[.appStorage("systemPrompt"), default: Preferences.defaultSystemPrompt]
    }
}

public extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {
    static var showsDockIcon: Self {
        Self[.appStorage("showsDockIcon"), default: false]
    }

    static var showsReasoning: Self {
        Self[.appStorage("showsReasoning"), default: true]
    }

    static var newThreadOnOpen: Self {
        Self[.appStorage("newThreadOnOpen"), default: false]
    }

    static var hasAppliedDefaultLoginItem: Self {
        Self[.appStorage("hasAppliedDefaultLoginItem"), default: false]
    }
}
