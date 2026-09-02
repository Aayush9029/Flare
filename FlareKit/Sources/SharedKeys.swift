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

public extension SharedReaderKey where Self == AppStorageKey<String>.Default {
    static var credentialPreference: Self {
        Self[.appStorage("credentialPreference"), default: CredentialPreference.automatic.rawValue]
    }

    static var panelPosition: Self {
        Self[.appStorage("panelPosition"), default: PanelPosition.bottomRight.rawValue]
    }

    static var panelSize: Self {
        Self[.appStorage("panelSize"), default: PanelSize.compact.rawValue]
    }
}

public extension SharedReaderKey where Self == AppStorageKey<Int>.Default {
    static var panelWidth: Self {
        Self[.appStorage("panelWidth"), default: Int(PanelSize.defaultWidth)]
    }
}

public extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {
    static var showsDockIcon: Self {
        Self[.appStorage("showsDockIcon"), default: false]
    }

    static var showsMenuBarIcon: Self {
        Self[.appStorage("showsMenuBarIcon"), default: true]
    }

    static var showsReasoning: Self {
        Self[.appStorage("showsReasoning"), default: true]
    }

    static var webSearchEnabled: Self {
        Self[.appStorage("webSearchEnabled"), default: true]
    }

    static var imagesEnabled: Self {
        Self[.appStorage("imagesEnabled"), default: true]
    }

    static var staysOnTop: Self {
        Self[.appStorage("staysOnTop"), default: false]
    }

    static var newThreadOnOpen: Self {
        Self[.appStorage("newThreadOnOpen"), default: false]
    }

    static var remembersPanelPosition: Self {
        Self[.appStorage("remembersPanelPosition"), default: true]
    }

    static var hasAppliedDefaultLoginItem: Self {
        Self[.appStorage("hasAppliedDefaultLoginItem"), default: false]
    }
}
