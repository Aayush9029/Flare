import FlareKit
import SwiftUI

struct ModelCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let model: ModelInfo
    let icon: String?
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var showInfo = false

    private var metrics: ModelMetrics? { model.metrics }
    private var context: String? { model.contextLabel ?? metrics?.context.flatMap { ModelInfo(id: model.id, context: $0).contextLabel } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProviderGlyph(icon: icon, symbol: symbol, size: 16)
                    .foregroundStyle(.primary)
                    .opacity(0.5)
                Text(model.shortName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                infoButton
            }

            if let metrics {
                HStack(spacing: 12) {
                    MetricBars(value: metrics.speed, maxValue: 5, color: .yellow)
                    MetricBars(value: metrics.intelligence, maxValue: 5, color: .purple)
                    if let context {
                        Text(context)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                HStack {
                    if let context {
                        Text(context)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(12)
        .background(.cardTile(colorScheme))
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? .blue : .primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .contentShape(.rect)
        .onTapGesture(perform: action)
    }

    @ViewBuilder
    private var infoButton: some View {
        Image(systemName: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .onHover { showInfo = $0 }
            .popover(isPresented: $showInfo, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Divider()

                    HStack(spacing: 6) {
                        MetricBars(value: 3, maxValue: 5, color: .yellow)
                        Text("Speed")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.yellow)
                    }
                    Text("Response time (more = faster)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack(spacing: 6) {
                        MetricBars(value: 4, maxValue: 5, color: .purple)
                        Text("Intelligence")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.purple)
                    }
                    Text("Model capability (more = smarter)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack(spacing: 6) {
                        Text(context ?? "Unknown")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Context")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("Max tokens the model can process")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(width: 220)
            }
    }
}
