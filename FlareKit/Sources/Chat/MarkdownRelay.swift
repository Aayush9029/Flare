import Foundation
import os

/// Broadcasts growing Markdown snapshots to any number of readers.
///
/// `StreamedMarkdownView` wants an `AsyncStream` of complete-so-far snapshots,
/// but SwiftUI may build the view more than once per assistant turn. Each
/// `stream()` therefore replays the current text before following new deltas.
public final class MarkdownRelay: Identifiable, @unchecked Sendable {
    public let id = UUID()

    private struct State {
        var text = ""
        var isFinished = false
        var continuations: [UUID: AsyncStream<String>.Continuation] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public init(text: String = "") {
        state.withLock { $0.text = text }
    }

    public var text: String {
        state.withLock { $0.text }
    }

    public var isEmpty: Bool {
        state.withLock { $0.text.isEmpty }
    }

    public func append(_ delta: String) {
        let snapshot = state.withLock { state -> String in
            state.text += delta
            return state.text
        }
        broadcast(snapshot)
    }

    public func finish() {
        let continuations = state.withLock { state -> [AsyncStream<String>.Continuation] in
            state.isFinished = true
            defer { state.continuations.removeAll() }
            return Array(state.continuations.values)
        }
        continuations.forEach { $0.finish() }
    }

    public func stream() -> AsyncStream<String> {
        AsyncStream { continuation in
            let key = UUID()
            let (snapshot, isFinished) = state.withLock { state -> (String, Bool) in
                if !state.isFinished { state.continuations[key] = continuation }
                return (state.text, state.isFinished)
            }
            continuation.yield(snapshot)
            if isFinished {
                continuation.finish()
                return
            }
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { _ = $0.continuations.removeValue(forKey: key) }
            }
        }
    }

    private func broadcast(_ snapshot: String) {
        let continuations = state.withLock { Array($0.continuations.values) }
        continuations.forEach { $0.yield(snapshot) }
    }
}
