import FlareKit
import SwiftUI

/// Renders a relay's Markdown: text runs in one TextKit 2 view each, tables as grids.
struct MarkdownMessageView: View {
    @State private var document: MarkdownDocumentModel
    @Environment(\.colorScheme) private var colorScheme

    init(relay: MarkdownRelay, theme: MarkdownTheme) {
        _document = State(initialValue: MarkdownDocumentModel(relay: relay, theme: theme))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(document.segments) { segment in
                switch segment {
                case .text(_, let text):
                    MarkdownTextRepresentable(text: text, markdownSource: { document.relay.text })
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .table(_, let table):
                    MarkdownTableView(table: table)
                }
            }
        }
        .task(id: document.relay.id) {
            await document.run(isDark: colorScheme == .dark)
        }
        .onChange(of: colorScheme) { _, scheme in
            document.setAppearance(isDark: scheme == .dark)
        }
        .onAppear {
            MarkdownImageAttachment.onLoad = { Task { @MainActor in document.refresh() } }
        }
    }
}
