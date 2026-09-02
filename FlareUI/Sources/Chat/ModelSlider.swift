import FlareKit
import SwiftUI

/// Five stops from Instant to Pro on one track. Letting go sets both the model
/// and the effort at once.
struct ModelSlider: View {
    @Bindable var preferences: Preferences
    /// The stop under the knob while a drag is in progress, for the label above.
    var onPreview: (ModelLevel?) -> Void = { _ in }
    var onCommit: () -> Void = {}

    private let levels = ModelLevel.allCases

    private var settled: Int {
        ModelLevel.matching(model: preferences.selectedModel, effort: preferences.effectiveEffort)?.rawValue
            ?? ModelLevel.medium.rawValue
    }

    var body: some View {
        StopSlider(count: levels.count, index: settled) { stop in
            onPreview(stop.map { levels[$0] })
        } onCommit: { stop in
            let level = levels[stop]
            preferences.$selectedModel.withLock { $0 = level.model }
            preferences.$reasoningEffort.withLock { $0 = level.effort }
            onCommit()
        }
        .accessibilityElement()
        .accessibilityLabel("Intelligence")
        .accessibilityValue(ModelLevel.matching(model: preferences.selectedModel, effort: preferences.effectiveEffort)?.title ?? preferences.model.displayName)
    }
}
