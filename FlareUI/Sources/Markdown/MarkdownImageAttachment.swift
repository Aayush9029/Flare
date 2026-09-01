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

    private func load() {
        let url = url
        Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url), let image = NSImage(data: data) else { return }
            await MainActor.run {
                Self.cache.withLock { $0[url] }?.install(image)
            }
        }
    }

    @MainActor
    private func install(_ image: NSImage) {
        let maxWidth: CGFloat = 400
        let scale = min(1, maxWidth / max(image.size.width, 1))
        bounds = CGRect(x: 0, y: 0, width: image.size.width * scale, height: image.size.height * scale)
        self.image = image
        Self.onLoad?()
    }
}
