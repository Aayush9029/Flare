import FlareKit
import SwiftUI

/// Where a message's reasoning stands: still thinking, or done in so many seconds.
struct ReasoningTiming {
    let isThinking: Bool
    let startedAt: Date?
    let seconds: Double

    @MainActor
    init(message: ChatMessage, model: FlareModel) {
        let isLatest = message.id == model.liveMessage?.id
        let started = isLatest ? model.liveReasoningStartedAt : nil
        let ended = isLatest ? model.liveReasoningEndedAt : nil
        isThinking = model.isStreaming && isLatest && started != nil && ended == nil
        startedAt = started
        if message.reasoningSeconds > 0 {
            seconds = message.reasoningSeconds
        } else if let started, let ended {
            seconds = ended.timeIntervalSince(started)
        } else {
            seconds = 0
        }
    }

    /// "Thinking · 4s" while it runs, "Thought for 12s" after, "Reasoning" when unknown.
    @ViewBuilder
    var title: some View {
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
