import FlareKit
import SwiftUI

struct CommandPaletteView: View {
    let model: FlareModel
    @FocusState private var isFocused: Bool

    private let radius: CGFloat = 18

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider().opacity(0.4)
            ZStack {
                if model.palette.hits.isEmpty {
                    emptyState
                } else {
                    results
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: radius))
        .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        .task {
            try? await Task.sleep(for: .milliseconds(40))
            isFocused = true
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search your chats", text: queryBinding)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($isFocused)
                .onSubmit(model.commitPaletteSelection)
                .onKeyPress(.upArrow) {
                    model.movePaletteHighlight(-1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    model.movePaletteHighlight(1)
                    return .handled
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.palette.hits) { hit in
                        Button {
                            model.closePalette()
                            model.selectThread(hit.threadID)
                        } label: {
                            CommandPaletteRow(
                                hit: hit,
                                isHighlighted: hit.id == model.palette.highlighted
                            )
                        }
                        .buttonStyle(.plain)
                        .id(hit.id)
                        .contextMenu {
                            Button("Delete Chat", role: .destructive) {
                                model.deleteThread(hit.threadID)
                                model.refreshPaletteResults()
                            }
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: model.palette.highlighted) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) }
            }
        }
    }

    private var emptyState: some View {
        Text(model.palette.query.isEmpty ? "No chats yet" : "No chats match “\(model.palette.query)”")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 16)
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { model.palette.query },
            set: model.updatePaletteQuery
        )
    }
}
