import Testing

@testable import FlareKit

@Suite("Model catalog")
struct ChatModelCatalogTests {
    @Test("Unknown ids fall back to the default model")
    func fallback() {
        #expect(ChatModelCatalog.option(id: "nope").id == ChatModelCatalog.default.id)
    }

    @Test("Known ids resolve")
    func lookup() {
        #expect(ChatModelCatalog.option(id: "gpt-5.6-sol").displayName == "GPT-5.6 Sol")
    }

    @Test("Every model offers at least one effort level")
    func efforts() {
        for option in ChatModelCatalog.all {
            #expect(!option.efforts.isEmpty)
        }
    }
}

@Suite("Preferences")
@MainActor
struct PreferencesTests {
    @Test("Effort is clamped to what the selected model supports")
    func clampsEffort() {
        let preferences = Preferences()
        preferences.$selectedModel.withLock { $0 = "gpt-5.6-luna" }
        preferences.$reasoningEffort.withLock { $0 = "xhigh" }

        #expect(preferences.model.efforts.contains(preferences.effectiveEffort))
        #expect(preferences.effectiveEffort != "xhigh")
    }

    @Test("A supported effort passes through unchanged")
    func keepsSupportedEffort() {
        let preferences = Preferences()
        preferences.$selectedModel.withLock { $0 = "gpt-5.6-sol" }
        preferences.$reasoningEffort.withLock { $0 = "xhigh" }

        #expect(preferences.effectiveEffort == "xhigh")
    }
}
