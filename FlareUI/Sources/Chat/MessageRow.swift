import AppKit
import Dependencies
import FlareKit
import SwiftUI

/// One message, streaming or stored. Assistant text always renders through the
/// relay the model hands out, so a row is never rebuilt when its answer lands.
struct MessageRow: View {
    let message: ChatMessage
    let model: FlareModel

    @Dependency(\.imageStore) private var imageStore

    private var isLatestAnswer: Bool { message.id == model.liveMessage?.id }
    private var isStreaming: Bool { model.isStreaming && isLatestAnswer }

    private var hasReasoning: Bool {
        isStreaming ? model.liveHasReasoning : !message.reasoning.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoleLabel(role: message.role, source: model.responseSource, isStreaming: isStreaming)

            if message.role == .user {
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(.primary.opacity(0.07), in: .rect(cornerRadius: 12, style: .continuous))
            } else {
                if model.preferences.showsReasoning, hasReasoning {
                    ReasoningDisclosure(relay: model.reasoningRelay(for: message), isStreaming: isStreaming)
                }

                MarkdownMessageView(relay: model.responseRelay(for: message), theme: .answer)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isLatestAnswer, !model.liveCitations.isEmpty {
                    CitationRow(citations: model.liveCitations)
                }
                if let url = imageStore.url(message.imageFile) {
                    GeneratedImage(url: url)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("Copy") { copy(MarkdownPlainText.from(markdown)) }
            Button("Copy as Markdown") { copy(markdown) }
        }
    }

    private var markdown: String {
        message.role == .user ? message.content : model.responseRelay(for: message).text
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
    var isStreaming = false

    var body: some View {
        HStack(spacing: 4) {
            if role == .user {
                Text("You")
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    FlareBolt()
                        .fill(FlareBolt.gradient)
                        .frame(width: 8, height: 9)
                    Text("Flare")
                        .foregroundStyle(FlareBolt.gradient)
                }
                .shimmer(isActive: isStreaming)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(source)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.medium))
    }
}

/// Open while the model is still reasoning, folded away once the answer lands.
private struct ReasoningDisclosure: View {
    let relay: MarkdownRelay
    let isStreaming: Bool
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            MarkdownMessageView(relay: relay, theme: .reasoning)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("Reasoning")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .onAppear { isExpanded = isStreaming }
        .onChange(of: isStreaming) { _, streaming in
            withAnimation(.easeInOut(duration: 0.25)) { isExpanded = streaming }
        }
    }
}
