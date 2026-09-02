import FlareKit
import SQLiteData
import SwiftUI

struct MessageListView: View {
    let threadID: ChatThread.ID
    let model: FlareModel

    @FetchAll private var messages: [ChatMessage]
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var isPinnedToBottom = true
    @Environment(\.transcriptBottomInset) private var bottomInset

    init(threadID: ChatThread.ID, model: FlareModel) {
        self.threadID = threadID
        self.model = model
        _messages = FetchAll(
            ChatMessage
                .where { $0.threadID.eq(threadID) }
                .order { $0.createdAt.asc() }
        )
    }

    /// The stored messages, plus the answer in flight until its stored row arrives.
    /// Both carry the same id, so the row keeps its identity across the handover.
    private var entries: [ChatMessage] {
        guard let live = model.liveMessage, live.threadID == threadID,
              !messages.contains(where: { $0.id == live.id })
        else { return messages }
        return messages + [live]
    }

    var body: some View {
        ScrollView {
            // Not lazy: a thread is short, and lazy rows estimate the height of the
            // text views underneath, which makes a bottom-anchored list jitter.
            VStack(alignment: .leading, spacing: 18) {
                ForEach(entries) { message in
                    MessageRow(message: message, model: model)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom)
        .contentMargins(.bottom, bottomInset, for: .scrollContent)
        .onChange(of: bottomInset) { _, _ in
            if isPinnedToBottom { position.scrollTo(edge: .bottom) }
        }
        .onScrollGeometryChange(for: ScrollMetrics.self, of: ScrollMetrics.init) { old, new in
            if new.contentHeight != old.contentHeight {
                // Content grew or shrank; follow it only if the reader was at the end.
                if isPinnedToBottom { position.scrollTo(edge: .bottom) }
            } else {
                isPinnedToBottom = new.isAtBottom
            }
        }
        .onChange(of: model.isStreaming) { _, isStreaming in
            if isStreaming { pinToBottom() }
        }
        .task(id: threadID) { pinToBottom() }
        .overlay {
            if messages.isEmpty, !model.isStreaming {
                EmptyChatView(source: model.responseSource)
            }
        }
    }

    private func pinToBottom() {
        isPinnedToBottom = true
        position.scrollTo(edge: .bottom)
    }
}

private struct ScrollMetrics: Equatable {
    let contentHeight: CGFloat
    let isAtBottom: Bool

    init(_ geometry: ScrollGeometry) {
        contentHeight = geometry.contentSize.height
        let visibleBottom = geometry.contentOffset.y + geometry.containerSize.height
        isAtBottom = visibleBottom >= geometry.contentSize.height - 24
    }
}

private struct EmptyChatView: View {
    let source: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Ask anything")
            } icon: {
                FlareBolt()
                    .fill(.secondary)
                    .frame(width: 26, height: 30)
            }
        } description: {
            Text("Answers stream from \(source). Every chat stays on this Mac.")
        }
    }
}
