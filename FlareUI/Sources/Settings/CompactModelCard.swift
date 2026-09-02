import FlareKit
import SwiftUI

/// A model in a grouped listing: name, context, and a check when chosen.
struct CompactModelCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let model: ModelInfo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.shortName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let context = model.contextLabel {
                        Text(context)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.cardTile(colorScheme))
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? .blue : .primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
