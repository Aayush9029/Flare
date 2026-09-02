import Dependencies
import FlareKit
import SwiftUI

struct CommandPaletteRow: View {
    let hit: SearchHit
    let isHighlighted: Bool

    @Dependency(\.imageStore) private var imageStore
    @State private var isHovering = false

    /// The newest image on the thread; a message may carry several, `|`-separated.
    private var thumbnail: URL? {
        hit.imageFile.split(separator: "|").first.flatMap { imageStore.url(String($0)) }
    }

    var body: some View {
        HStack(spacing: 10) {
            if let thumbnail {
                AsyncImage(url: thumbnail) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.primary.opacity(0.06)
                }
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(hit.displayTitle)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if !hit.snippet.isEmpty {
                    Text(hit.snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(hit.updatedAt, format: .relative(presentation: .numeric))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            .primary.opacity(isHighlighted ? 0.14 : (isHovering ? 0.07 : 0)),
            in: .rect(cornerRadius: 10, style: .continuous)
        )
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? [.isButton, .isSelected] : .isButton)
    }
}
