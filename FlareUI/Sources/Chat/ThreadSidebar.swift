import FlareKit
import SQLiteData
import SwiftUI

struct ThreadSidebar: View {
    let model: FlareModel

    @FetchAll(ChatThread.order { $0.updatedAt.desc() }) private var threads: [ChatThread]
    @State private var hoveredID: ChatThread.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            List(selection: Binding(
                get: { model.selectedThreadID },
                set: { if let id = $0 { model.selectThread(id) } }
            )) {
                ForEach(threads) { thread in
                    row(thread)
                        .tag(thread.id)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 220)
        .background(.black.opacity(0.12))
    }

    private var header: some View {
        HStack {
            Text("Chats")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: model.newThread) {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .help("New chat (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func row(_ thread: ChatThread) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(thread.displayTitle)
                    .lineLimit(1)
                    .font(.callout)
                Text(thread.updatedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)

            if hoveredID == thread.id {
                Button {
                    model.deleteThread(thread.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Delete chat")
            }
        }
        .contentShape(.rect)
        .onHover { hoveredID = $0 ? thread.id : nil }
        .contextMenu {
            Button("Delete", role: .destructive) { model.deleteThread(thread.id) }
        }
    }
}
