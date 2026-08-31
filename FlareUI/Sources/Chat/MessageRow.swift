import FlareKit
import SwiftUI
import SwiftStreamingMarkdown

struct MessageRow: View {
    let role: ChatMessage.Role
    let content: String
    let reasoning: String
    let showsReasoning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoleLabel(role: role)

            if showsReasoning, !reasoning.isEmpty {
                ReasoningDisclosure(text: reasoning)
            }

            if role == .user {
                Text(content)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(.primary.opacity(0.07), in: .rect(cornerRadius: 12, style: .continuous))
            } else {
                MarkdownView(text: content)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The assistant turn while it streams. Identity is tied to the relay so a
/// rebuild replays the snapshot instead of restarting the parse from empty.
struct StreamingMessageRow: View {
    let response: MarkdownRelay
    let reasoning: MarkdownRelay
    let showsReasoning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoleLabel(role: .assistant)

            if showsReasoning {
                StreamedMarkdownView(source: RelayMarkdownSource(relay: reasoning))
                    .id(reasoning.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            StreamedMarkdownView(source: RelayMarkdownSource(relay: response))
                .id(response.id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RoleLabel: View {
    let role: ChatMessage.Role

    var body: some View {
        HStack(spacing: 4) {
            if role == .user {
                Text("You")
            } else {
                Image(systemName: "sparkle")
                Text("Flare")
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(role == .user ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange.gradient))
    }
}

private struct ReasoningDisclosure: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Reasoning")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
