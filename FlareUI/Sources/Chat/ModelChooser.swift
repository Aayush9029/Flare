import FlareKit
import SwiftUI

/// The picker's body: how hard the chosen model thinks, on one track. The model and
/// the provider are chosen in Settings.
struct ModelChooser: View {
    let providers: ProviderCatalog
    /// A drag began: hold the card open.
    var onInteract: () -> Void = {}
    /// The hand let go: the card may close on its own.
    var onSettle: () -> Void = {}
    var openSettings: () -> Void = {}

    @State private var previewEffort: String?

    private var provider: ProviderInfo { providers.active }
    private var selection: ModelSelection { providers.selection }
    private var efforts: [String] { provider.efforts(for: selection.model) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ProviderGlyph(icon: provider.icon, symbol: provider.kind.symbol, size: 12)
                    .foregroundStyle(.secondary)
                Text(provider.modelName(selection.model))
                    .font(.headline)
                    .lineLimit(1)
            }
            if efforts.isEmpty {
                Text("This model has no reasoning setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(Effort.title(previewEffort ?? selection.effort))
                    .font(.title3.weight(.semibold))
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.12), value: previewEffort)
                EffortSlider(efforts: efforts, effort: selection.effort) { effort in
                    previewEffort = effort
                    if effort != nil { onInteract() }
                } onCommit: { effort in
                    providers.select(ModelSelection(model: selection.model, effort: effort == Effort.none ? nil : effort))
                    onSettle()
                }
                .padding(.horizontal, 12)
                Text(detail(for: previewEffort ?? selection.effort))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                openSettings()
            } label: {
                HStack(spacing: 4) {
                    Text("Change model in Settings")
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 8, weight: .semibold))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func detail(for effort: String?) -> String {
        switch effort {
        case nil, Effort.none: "No reasoning setting is sent; the model decides."
        case Effort.low: "Quick answers and lookups."
        case Effort.medium: "The everyday default."
        case Effort.high: "More thought on harder questions."
        case Effort.extraHigh: "Thinking as long as it takes."
        default: ""
        }
    }
}
