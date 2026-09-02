import FlareKit
import SwiftUI

/// Flare's own addition under the model grid: how hard the chosen model thinks, on
/// the same track as the panel's picker.
struct ReasoningCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let efforts: [String]
    let effort: String?
    let onCommit: (String) -> Void

    @State private var preview: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reasoning")
                .font(.headline)

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "brain")
                        .font(.system(size: 20))
                        .foregroundStyle(.purple)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EFFORT")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(Effort.title(preview ?? effort))
                            .font(.subheadline.weight(.medium))
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.12), value: preview)
                    }
                    Spacer()
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(12)
                .background(.cardTop(colorScheme))

                EffortSlider(efforts: efforts, effort: effort) { preview = $0 } onCommit: { onCommit($0) }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.cardBottom(colorScheme))
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            }
        }
    }

    private var detail: String {
        efforts.contains(Effort.none)
            ? "Off sends no reasoning setting; the server decides."
            : "Higher means slower, more considered answers."
    }
}
