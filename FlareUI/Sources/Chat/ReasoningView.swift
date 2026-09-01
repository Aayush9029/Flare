import FlareKit
import SwiftUI

/// The model's reasoning, shown the way current reasoning UIs do: while it thinks,
/// a shimmering "Thinking" line over a short window that follows the newest
/// lines; once the answer starts, a "Thought for" line that opens on click.
struct ReasoningView: View {
    let relay: MarkdownRelay
    let isThinking: Bool
    let startedAt: Date?
    let seconds: Double

    @State private var isExpanded = false
    @State private var userToggled = false

    private static let peekHeight: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                userToggled = true
                withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    header
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .shimmer(isActive: isThinking)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide reasoning" : "Show reasoning")

            if isExpanded {
                reasoning
                    .transition(.opacity)
            } else if isThinking {
                reasoning
                    .frame(maxHeight: Self.peekHeight, alignment: .bottom)
                    .clipped()
                    .mask {
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onChange(of: isThinking) { _, thinking in
            guard !thinking, !userToggled else { return }
            withAnimation(.easeInOut(duration: 0.22)) { isExpanded = false }
        }
    }

    private var reasoning: some View {
        MarkdownMessageView(relay: relay, theme: .reasoning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.primary.opacity(0.12))
                    .frame(width: 2)
            }
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
