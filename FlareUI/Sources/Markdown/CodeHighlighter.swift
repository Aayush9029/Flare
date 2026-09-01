import AppKit
import HighlightSwift

/// Highlights finished code blocks once and remembers the result. Results carry
/// literal colours, so light and dark are cached apart.
actor CodeHighlighter {
    static let shared = CodeHighlighter()

    struct Key: Hashable {
        let code: String
        let language: String
        let isDark: Bool
    }

    private let highlight = Highlight()
    private var results: [Key: NSAttributedString] = [:]
    private var inFlight: Set<Key> = []

    nonisolated func cached(_ key: Key) -> NSAttributedString? {
        cache.withLock { $0[key] }
    }

    private nonisolated let cache = Lock<[Key: NSAttributedString]>([:])

    /// Starts a highlight if none is cached or running; `onReady` fires once per key.
    func request(_ key: Key, onReady: @escaping @Sendable () -> Void) async {
        guard cached(key) == nil, !inFlight.contains(key) else { return }
        inFlight.insert(key)
        let colors: HighlightColors = key.isDark ? .dark(.xcode) : .light(.xcode)
        let text: AttributedString
        do {
            text = key.language.isEmpty
                ? try await highlight.attributedText(key.code, colors: colors)
                : try await highlight.attributedText(key.code, language: key.language, colors: colors)
        } catch {
            text = AttributedString(key.code)
        }
        cache.withLock { $0[key] = NSAttributedString(text) }
        inFlight.remove(key)
        onReady()
    }
}

/// The smallest lock that lets a `nonisolated` reader see the actor's cache.
final class Lock<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body(&value)
    }
}
