import AppKit

/// One attachment per URL, shared across rebuilds so the tail diff sees an
/// unchanged paragraph and the image is not torn down on every token.
final class MarkdownImageAttachment: NSTextAttachment, @unchecked Sendable {
    private static let cache = Lock<[URL: MarkdownImageAttachment]>([:])
    @MainActor static var onLoad: (() -> Void)?

    let url: URL

    static func shared(for url: URL) -> MarkdownImageAttachment {
        let (attachment, isNew) = cache.withLock { cache -> (MarkdownImageAttachment, Bool) in
            if let existing = cache[url] { return (existing, false) }
            let attachment = MarkdownImageAttachment(url: url)
            cache[url] = attachment
            return (attachment, true)
        }
        if isNew { attachment.load() }
        return attachment
    }

    private init(url: URL) {
        self.url = url
        super.init(data: nil, ofType: nil)
        bounds = CGRect(x: 0, y: 0, width: 240, height: 140)
    }

    required init?(coder: NSCoder) { nil }

    // The detached task moves only `Data` and `URL` and hands off to a static
    // main-actor function. Swift 6.3.3's region checker rejects a `MainActor.run`
    // closure that reaches the attachment through the lock.
    private func load() {
        let url = url
        Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return }
            await Self.install(data, for: url)
        }
    }

    @MainActor
    private static func install(_ data: Data, for url: URL) {
        guard let image = NSImage(data: data), let attachment = cache.withLock({ $0[url] }) else { return }
        let maxWidth: CGFloat = 400
        let scale = min(1, maxWidth / max(image.size.width, 1))
        attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width * scale, height: image.size.height * scale)
        attachment.image = image
        onLoad?()
    }
}
