import FlareKit
import SwiftUI

/// A message's reasoning across the whole panel. Escape or the close button
/// returns to the chat, which waits underneath untouched.
struct ThoughtsView: View {
    let message: ChatMessage
    let model: FlareModel

    @State private var position = ScrollPosition(edge: .bottom)

    private var timing: ReasoningTiming { ReasoningTiming(message: message, model: model) }

    var body: some View {
        let timing = timing
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                timing.title
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .shimmer(isActive: timing.isThinking)
                Spacer()
                Text("esc")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.primary.opacity(0.07), in: .rect(cornerRadius: 4))
                Button {
                    withAnimation(Morph.animation) { model.dismissReasoning() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Close reasoning")
                .help("Back to the chat (Esc)")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider().opacity(0.5)

            ScrollView {
                MarkdownMessageView(relay: model.reasoningRelay(for: message), theme: .thoughts)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .scrollPosition($position)
            .defaultScrollAnchor(timing.isThinking ? .bottom : .top)
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentSize.height }) { _, _ in
                if timing.isThinking { position.scrollTo(edge: .bottom) }
            }
        }
        .background(PanelScrim())
    }
}
