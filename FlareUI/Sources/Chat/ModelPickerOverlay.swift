import FlareKit
import SwiftUI

/// The slider over the composer, with the chosen stop named above it. A click
/// anywhere else, or Escape, puts it away.
struct ModelPickerOverlay: View {
    let model: FlareModel

    @State private var preview: ModelLevel?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.001)
                .contentShape(.rect)
                .onTapGesture { model.dismissModelPicker() }

            VStack(spacing: 12) {
                Text(ModelLabel.text(for: model.preferences, preview: preview))
                    .font(.headline)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.12), value: preview)
                ModelSlider(preferences: model.preferences) { preview = $0 }
                    .padding(.horizontal, 28)
                Text((preview ?? ModelLevel.matching(model: model.preferences.selectedModel, effort: model.preferences.effectiveEffort))?.detail ?? model.preferences.model.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 96)
        }
    }
}

enum ModelLabel {
    /// "5.6 High" for a stop, or the model and effort by name for a custom pairing.
    @MainActor
    static func text(for preferences: Preferences, preview: ModelLevel? = nil) -> String {
        if let level = preview ?? ModelLevel.matching(model: preferences.selectedModel, effort: preferences.effectiveEffort) {
            return "5.6 \(level.title)"
        }
        return "\(preferences.model.shortName) · \(preferences.effectiveEffort.capitalized)"
    }
}
