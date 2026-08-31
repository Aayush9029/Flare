import Observation
import Sharing

@MainActor
@Observable
public final class Preferences {
    @ObservationIgnored @Shared(.selectedModel) public var selectedModel: String
    @ObservationIgnored @Shared(.reasoningEffort) public var reasoningEffort: String
    @ObservationIgnored @Shared(.systemPrompt) public var systemPrompt: String
    @ObservationIgnored @Shared(.showsDockIcon) public var showsDockIcon: Bool
    @ObservationIgnored @Shared(.showsReasoning) public var showsReasoning: Bool
    @ObservationIgnored @Shared(.newThreadOnOpen) public var newThreadOnOpen: Bool
    @ObservationIgnored @Shared(.hasAppliedDefaultLoginItem) public var hasAppliedDefaultLoginItem: Bool

    public static let defaultSystemPrompt = """
    You are Flare, a quick-answer assistant living in a floating window on macOS.
    Answer directly and concisely. Lead with the answer, then add only the detail that changes what the reader does.
    Use Markdown: fenced code blocks with a language, tables when comparing, and short lists.
    """

    public init() {}

    public var model: ChatModelOption {
        ChatModelCatalog.option(id: selectedModel)
    }

    /// Clamps the stored effort to one the selected model actually offers.
    public var effectiveEffort: String {
        model.efforts.contains(reasoningEffort) ? reasoningEffort : (model.efforts.last ?? "medium")
    }
}
