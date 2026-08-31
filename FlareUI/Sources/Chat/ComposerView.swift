import FlareKit
import SwiftUI

struct ComposerView: View {
    @Bindable var model: FlareModel
    @FocusState private var isFocused: Bool

    private let radius: CGFloat = 14

    var body: some View {
        VStack(spacing: 8) {
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .bottom, spacing: 10) {
                Image(systemName: "sparkle")
                    .foregroundStyle(model.isStreaming ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(.secondary))
                    .padding(.bottom, 4)

                TextField(
                    model.isStreaming ? "Thinking…" : "Ask anything…",
                    text: $model.draft,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .font(.body)
                .focused($isFocused)
                .onSubmit(model.send)

                trailingButton
            }
            .padding(12)
            .background(.black.opacity(0.18), in: .rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.primary.opacity(isFocused ? 0.22 : 0.1), lineWidth: 1)
            }
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .onAppear { isFocused = true }
        .task(id: model.selectedThreadID) { isFocused = true }
    }

    @ViewBuilder
    private var trailingButton: some View {
        if model.isStreaming {
            Button(action: model.stopStreaming) {
                Image(systemName: "stop.fill")
                    .font(.caption)
                    .padding(6)
            }
            .buttonBorderShape(.circle)
            .help("Stop (⌘.)")
        } else {
            Button(action: model.send) {
                Image(systemName: "arrow.up")
                    .font(.caption.weight(.bold))
                    .padding(6)
            }
            .buttonBorderShape(.circle)
            .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Send (Return)")
        }
    }
}
