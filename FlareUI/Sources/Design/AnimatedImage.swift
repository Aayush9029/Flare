import AppKit
import ImageIO
import SwiftUI

struct AnimatedImage: NSViewRepresentable {
    let resource: String

    func makeNSView(context: Context) -> AnimatedImageView {
        AnimatedImageView(resource: resource)
    }

    func updateNSView(_ view: AnimatedImageView, context: Context) {}
}

/// Plays a GIF from frames decoded off the main thread, only while its window shows.
/// An animating NSImageView, and ImageIO's own animator, both decoded every frame on
/// the main thread: 120 ms of the first Settings open.
final class AnimatedImageView: NSView {
    private let url: URL?
    private var player: GIFPlayer?
    private var occlusionObserver: NSObjectProtocol?

    init(resource: String) {
        url = Bundle.main.url(forResource: resource, withExtension: "gif")
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contentsGravity = .resize
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        player?.stop()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
        occlusionObserver = nil
        updatePlayback()
        guard let window else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePlayback() }
        }
    }

    private func updatePlayback() {
        guard let url, let window, window.occlusionState.contains(.visible) else {
            player?.stop()
            player = nil
            return
        }
        guard player == nil else { return }
        // Frames drawn in the screen's colour space commit without a conversion.
        let space = window.screen?.colorSpace?.cgColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let player = GIFPlayer(url: url, colorSpace: space)
        player.play { [weak self] frame in self?.layer?.contents = frame }
        self.player = player
    }
}

private final class GIFPlayer: @unchecked Sendable {
    private let url: URL
    private let colorSpace: CGColorSpace
    private let queue = DispatchQueue(label: "ca.optimalapps.flare.gif", qos: .utility)
    private let lock = NSLock()
    private var isStopped = false

    init(url: URL, colorSpace: CGColorSpace) {
        self.url = url
        self.colorSpace = colorSpace
    }

    func play(_ show: @escaping @MainActor (CGImage) -> Void) {
        queue.async {
            guard let source = CGImageSourceCreateWithURL(self.url as CFURL, nil) else { return }
            let delays = (0..<CGImageSourceGetCount(source)).map { index in
                let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
                let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                    ?? gif?[kCGImagePropertyGIFDelayTime] as? Double
                    ?? 0.1
                return delay < 0.02 ? 0.1 : delay
            }
            guard !delays.isEmpty else { return }
            self.step(0, source: source, delays: delays, show: show)
        }
    }

    func stop() {
        lock.withLock { isStopped = true }
    }

    private func step(_ index: Int, source: CGImageSource, delays: [Double], show: @escaping @MainActor (CGImage) -> Void) {
        guard !lock.withLock({ isStopped }),
              let image = CGImageSourceCreateImageAtIndex(source, index, nil),
              let frame = bitmap(image)
        else { return }
        DispatchQueue.main.async { show(frame) }
        queue.asyncAfter(deadline: .now() + delays[index]) {
            self.step((index + 1) % delays.count, source: source, delays: delays, show: show)
        }
    }

    /// An ImageIO frame stays encoded until something draws it, and Core Animation
    /// would draw it during the main thread's commit. A plain bitmap commits as it is.
    private func bitmap(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
