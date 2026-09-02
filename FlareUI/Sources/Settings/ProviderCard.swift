import FlareKit
import SwiftUI

struct ProviderCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let provider: ProviderInfo
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(provider.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(.cardTop(colorScheme))

            HStack(alignment: .bottom) {
                Text(provider.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Spacer()
                ProviderGlyph(icon: provider.icon, symbol: provider.kind.symbol, size: 24)
                    .foregroundStyle(.primary)
                    .opacity(0.6)
            }
            .padding(12)
            .background(.cardBottom(colorScheme))
        }
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? .blue : .primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .contentShape(.rect)
    }
}
