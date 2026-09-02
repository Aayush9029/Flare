import SwiftUI

/// The last card in the grid: a custom OpenAI-compatible server.
struct AddEndpointCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Endpoint")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .padding(12)
            .background(.cardTop(colorScheme))

            HStack(alignment: .bottom) {
                Text("Ollama, LM Studio, llama.cpp, vLLM, Mistral, xAI, or any OpenAI-compatible server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Spacer()
                Image(systemName: "server.rack")
                    .font(.system(size: 20, weight: .medium))
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
