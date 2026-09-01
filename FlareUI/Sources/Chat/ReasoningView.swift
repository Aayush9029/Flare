import FlareKit
import SwiftUI

/// The model's reasoning as a card, after Grok's: a header with the elapsed time,
/// section titles over muted lines that follow the newest text while it thinks,
/// and only the header once the answer starts, opened again by a click.
struct ReasoningView: View {
    let relay: MarkdownRelay
    let isThinking: Bool
    let startedAt: Date?
    let seconds: Double

    @State private var isExpanded = false
    @State private var userToggled = false

    private static let peekHeight: CGFloat = 96
    private static let radius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                userToggled = true
                withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    header
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .shimmer(isActive: isThinking)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide reasoning" : "Show reasoning")

            if isExpanded {
                Divider().opacity(0.5)
                reasoning
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .transition(.opacity)
            } else if isThinking {
                Divider().opacity(0.5)
                reasoning
                    .frame(maxHeight: Self.peekHeight, alignment: .bottom)
                    .clipped()
                    .mask {
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.4)],
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
        .onChange(of: isThinking) { _, thinking in
            guard !thinking, !userToggled else { return }
            withAnimation(.easeInOut(duration: 0.22)) { isExpanded = false }
        }
    }

    private var reasoning: some View {
        MarkdownMessageView(relay: relay, theme: .reasoning)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var header: some View {
        if isThinking, let startedAt {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                let elapsed = Int(context.date.timeIntervalSince(startedAt))
                Text(elapsed < 2 ? "Thinking…" : "Thinking · \(Self.duration(Double(elapsed)))")
            }
        } else if isThinking {
            Text("Thinking…")
        } else if seconds >= 1 {
            Text("Thought for \(Self.duration(seconds))")
        } else {
            Text("Reasoning")
        }
    }

    static func duration(_ seconds: Double) -> String {
        let whole = Int(seconds.rounded())
        return whole < 60 ? "\(whole)s" : "\(whole / 60)m \(whole % 60)s"
    }
}
