import Observation
import Sharing

@MainActor
@Observable
public final class Preferences {
    @ObservationIgnored @Shared(.selectedModel) public var selectedModel: String
    @ObservationIgnored @Shared(.reasoningEffort) public var reasoningEffort: String
    @ObservationIgnored @Shared(.systemPrompt) public var systemPrompt: String
    @ObservationIgnored @Shared(.credentialPreference) public var credentialPreferenceRaw: String
    @ObservationIgnored @Shared(.showsDockIcon) public var showsDockIcon: Bool
    @ObservationIgnored @Shared(.showsReasoning) public var showsReasoning: Bool
    @ObservationIgnored @Shared(.webSearchEnabled) public var webSearchEnabled: Bool
    @ObservationIgnored @Shared(.imagesEnabled) public var imagesEnabled: Bool
    @ObservationIgnored @Shared(.staysOnTop) public var staysOnTop: Bool
    @ObservationIgnored @Shared(.newThreadOnOpen) public var newThreadOnOpen: Bool
    @ObservationIgnored @Shared(.remembersPanelPosition) public var remembersPanelPosition: Bool
    @ObservationIgnored @Shared(.panelPosition) public var panelPositionRaw: String
    @ObservationIgnored @Shared(.panelSize) public var panelSizeRaw: String
    @ObservationIgnored @Shared(.hasAppliedDefaultLoginItem) public var hasAppliedDefaultLoginItem: Bool

    public nonisolated static let defaultSystemPrompt = """
    You are Flare, a quick-answer assistant living in a floating window on macOS.
    Answer directly and concisely. Lead with the answer, then add only the detail that changes what the reader does.
    Use Markdown: fenced code blocks with a language, tables when comparing, and short lists.
    """

    public init() {}

    public var credentialPreference: CredentialPreference {
        CredentialPreference(rawValue: credentialPreferenceRaw) ?? .automatic
    }

    public var panelPosition: PanelPosition {
        PanelPosition(rawValue: panelPositionRaw) ?? .bottomRight
    }

    public var panelSize: PanelSize {
        PanelSize(rawValue: panelSizeRaw) ?? .compact
    }

    public var model: ChatModelOption {
        ChatModelCatalog.option(id: selectedModel)
    }

    public var effectiveEffort: String {
        model.efforts.contains(reasoningEffort) ? reasoningEffort : (model.efforts.last ?? "medium")
    }
}
