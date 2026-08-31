import FlareKit
import SQLiteData
import SwiftUI

struct MessageListView: View {
    let threadID: ChatThread.ID
    let model: FlareModel

    @FetchAll private var messages: [ChatMessage]
    @Namespace private var bottom

    init(threadID: ChatThread.ID, model: FlareModel) {
        self.threadID = threadID
        self.model = model
        _messages = FetchAll(
            ChatMessage
                .where { $0.threadID.eq(threadID) }
                .order { $0.createdAt.asc() }
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(messages) { message in
                        MessageRow(
                            role: message.role,
                            content: message.content,
                            reasoning: message.reasoning,
                            showsReasoning: model.preferences.showsReasoning
                        )
                    }

                    if let response = model.liveResponse, let reasoning = model.liveReasoning {
                        StreamingMessageRow(
                            response: response,
                            reasoning: reasoning,
                            showsReasoning: model.preferences.showsReasoning
                        )
                    }

                    Color.clear.frame(height: 1).id(bottom)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay {
                if messages.isEmpty, !model.isStreaming {
                    EmptyChatView()
                }
            }
            .onChange(of: messages.count) { scrollToBottom(proxy) }
            .onChange(of: model.isStreaming) { scrollToBottom(proxy) }
            .task(id: threadID) { scrollToBottom(proxy) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottom, anchor: .bottom)
        }
    }
}

private struct EmptyChatView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Ask anything", systemImage: "sparkle")
        } description: {
            Text("Flare answers with your ChatGPT account and keeps every chat on this Mac.")
        }
    }
}
