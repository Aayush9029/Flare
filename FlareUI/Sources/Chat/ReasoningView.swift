import FlareKit
import SwiftUI

/// The model's reasoning as a card, after Grok's: a header with the elapsed time
/// over muted lines that follow the newest text while it thinks, then only the
/// header once the answer starts. A click opens the thoughts across the panel.
struct ReasoningView: View {
    let message: ChatMessage
    let model: FlareModel

    @State private var document: MarkdownDocumentModel

    private static let peekHeight: CGFloat = 72
    private static let radius: CGFloat = 12

    init(message: ChatMessage, model: FlareModel) {
        self.message = message
        self.model = model
        _document = State(initialValue: MarkdownDocumentModel(relay: model.reasoningRelay(for: message), theme: .reasoning))
    }

    private var timing: ReasoningTiming { ReasoningTiming(message: message, model: model) }

    var body: some View {
        let timing = timing
        VStack(alignment: .leading, spacing: 0) {
            Button {
                model.showReasoning(for: message)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    timing.title
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .shimmer(isActive: timing.isThinking)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open reasoning")
            .help("Read the thoughts")

            if timing.isThinking {
                Divider().opacity(0.5)
                // Older lines soften as well as fade: a blurred copy of the same
                // model sits over the top of the sharp one.
                ZStack(alignment: .bottom) {
                    reasoning
                    reasoning
                        .blur(radius: 2.5)
                        .mask {
                            LinearGradient(
                                stops: [.init(color: .black, location: 0), .init(color: .clear, location: 0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }
                .frame(maxHeight: Self.peekHeight, alignment: .bottom)
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .background(.primary.opacity(0.045), in: .rect(cornerRadius: Self.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.22), value: timing.isThinking)
    }

    private var reasoning: some View {
        MarkdownMessageView(document: document)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
