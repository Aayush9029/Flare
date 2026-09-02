import FlareKit
import SwiftUI

/// The slider in a card over the composer, with the chosen stop named above it.
/// A click anywhere else, Escape, or three seconds after letting go put it away.
struct ModelPickerOverlay: View {
    let model: FlareModel

    @Environment(\.colorScheme) private var colorScheme
    @State private var preview: ModelLevel?
    @State private var dismissal: Task<Void, Never>?

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
                ModelSlider(preferences: model.preferences) { level in
                    preview = level
                    if level != nil { dismissal?.cancel() }
                } onCommit: {
                    scheduleDismissal()
                }
                .padding(.horizontal, 12)
                Text((preview ?? ModelLevel.matching(model: model.preferences.selectedModel, effort: model.preferences.effectiveEffort))?.detail ?? model.preferences.model.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(cardFill, in: .rect(cornerRadius: 22, style: .continuous))
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 18, y: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onDisappear { dismissal?.cancel() }
    }

    /// Soft white in light mode, deep glass in dark.
    private var cardFill: Color {
        colorScheme == .dark ? .black.opacity(0.45) : .white.opacity(0.82)
    }

    private func scheduleDismissal() {
        dismissal?.cancel()
        dismissal = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            model.dismissModelPicker()
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
