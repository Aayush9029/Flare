import Foundation
import os

/// Emits growing snapshots, not deltas; a late subscriber replays the current text first.
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
            // Register and replay atomically, or a concurrent append can broadcast
            // a longer snapshot before this one and the text appears to go backwards.
            let isFinished = state.withLock { state -> Bool in
                if !state.isFinished { state.continuations[key] = continuation }
                continuation.yield(state.text)
                return state.isFinished
            }
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
