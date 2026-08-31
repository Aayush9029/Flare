import AppKit
import Dependencies
import FlareKit
import SwiftUI
import SwiftStreamingMarkdown

struct MessageRow: View {
    let role: ChatMessage.Role
    let content: String
    let reasoning: String
    let showsReasoning: Bool
    let source: String
    var imageFile: String = ""

    @Dependency(\.imageStore) private var imageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoleLabel(role: role, source: source)

            if showsReasoning, !reasoning.isEmpty {
                ReasoningDisclosure(text: reasoning)
            }

            if role == .user {
                Text(content)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(.primary.opacity(0.07), in: .rect(cornerRadius: 12, style: .continuous))
            } else {
                // The package renders paragraphs through an NSViewRepresentable, which
                // collapses to zero height unless it is given a definite width.
                if !content.isEmpty {
                    MarkdownView(text: content, config: MarkdownStyle.config)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let url = imageStore.url(imageFile) {
                    GeneratedImage(url: url)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("Copy") { copy(MarkdownPlainText.from(content)) }
            Button("Copy as Markdown") { copy(content) }
        }
    }
}

struct StreamingMessageRow: View {
    let response: MarkdownRelay
    let reasoning: MarkdownRelay
    let showsReasoning: Bool
    let source: String
    let citations: [Citation]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoleLabel(role: .assistant, source: source)

            if showsReasoning {
                StreamedMarkdownView(source: RelayMarkdownSource(relay: reasoning), config: MarkdownStyle.config)
                    .id(reasoning.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            StreamedMarkdownView(source: RelayMarkdownSource(relay: response), config: MarkdownStyle.config)
                .id(response.id)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if !citations.isEmpty {
                CitationRow(citations: citations)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GeneratedImage: View {
    let url: URL
    @State private var isHovering = false

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.06))
                .frame(height: 180)
                .overlay { ProgressView().controlSize(.small) }
        }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.forward.square.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Open full size")
            }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy Image") {
                guard let image = NSImage(contentsOf: url) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
            Button("Save to Downloads…") {
                let destination = URL.downloadsDirectory.appending(path: url.lastPathComponent)
                try? FileManager.default.copyItem(at: url, to: destination)
            }
        }
        .accessibilityLabel("Generated image")
    }
}

private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

struct CitationRow: View {
    let citations: [Citation]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(citations.prefix(4)) { citation in
                Link(citation.host, destination: URL(string: citation.url) ?? URL(string: "https://openai.com")!)
                    .font(.caption2)
                    .lineLimit(1)
                    .help(citation.title)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

private struct RoleLabel: View {
    let role: ChatMessage.Role
    let source: String

    var body: some View {
        HStack(spacing: 4) {
            if role == .user {
                Text("You")
                    .foregroundStyle(.secondary)
            } else {
                FlareBolt()
                    .fill(FlareBolt.gradient)
                    .frame(width: 8, height: 9)
                Text("Flare")
                    .foregroundStyle(FlareBolt.gradient)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(source)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.medium))
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
