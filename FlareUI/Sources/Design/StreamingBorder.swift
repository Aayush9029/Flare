import AppKit
import SwiftUI

/// A hue that travels around the composer while a response streams.
struct StreamingBorder: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    StreamingRing(cornerRadius: cornerRadius)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: isActive)
    }
}

extension View {
    func streamingBorder(isActive: Bool, cornerRadius: CGFloat) -> some View {
        modifier(StreamingBorder(isActive: isActive, cornerRadius: cornerRadius))
    }
}

/// Core Animation turns the gradient in the render server. A TimelineView here, with the
/// one in the shimmer, re-rendered the panel on every display frame of a stream.
private struct StreamingRing: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> StreamingRingView {
        StreamingRingView(cornerRadius: cornerRadius)
    }

    func updateNSView(_ view: StreamingRingView, context: Context) {}
}

private final class StreamingRingView: NSView {
    private let cornerRadius: CGFloat
    private let ring = Ring(lineWidth: 2)
    private let glow = Ring(lineWidth: 4)
    private let glowHost = CALayer()
    private static let glowSpread: CGFloat = 24

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        layerUsesCoreImageFilters = true
        glowHost.addSublayer(glow.layer)
        glowHost.opacity = 0.7
        glowHost.filters = [CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 7]) as Any]
        layer?.addSublayer(glowHost)
        layer?.addSublayer(ring.layer)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let spread = Self.glowSpread
        ring.layout(in: bounds, shape: bounds, cornerRadius: cornerRadius)
        glowHost.frame = bounds.insetBy(dx: -spread, dy: -spread)
        glow.layout(
            in: glowHost.bounds,
            shape: CGRect(x: spread, y: spread, width: bounds.width, height: bounds.height),
            cornerRadius: cornerRadius
        )
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        updateScale()
        ring.turn()
        glow.turn()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateScale()
    }

    private func updateScale() {
        let scale = window?.backingScaleFactor ?? 2
        ring.mask.contentsScale = scale
        glow.mask.contentsScale = scale
    }
}

/// A conic gradient, larger than the ring, seen through a stroked rounded rectangle.
private struct Ring {
    let layer = CALayer()
    let mask = CAShapeLayer()
    let disc = CAGradientLayer()
    let lineWidth: CGFloat

    private static let colors: [CGColor] = [
        NSColor(srgbRed: 0.66, green: 0.48, blue: 1.00, alpha: 1).cgColor,
        NSColor(srgbRed: 0.48, green: 0.25, blue: 0.89, alpha: 1).cgColor,
        NSColor(srgbRed: 0.29, green: 0.12, blue: 0.66, alpha: 1).cgColor,
        NSColor(srgbRed: 0.66, green: 0.48, blue: 1.00, alpha: 1).cgColor,
    ]

    init(lineWidth: CGFloat) {
        self.lineWidth = lineWidth
        disc.type = .conic
        disc.colors = Self.colors
        disc.startPoint = CGPoint(x: 0.5, y: 0.5)
        disc.endPoint = CGPoint(x: 1, y: 0.5)
        mask.fillColor = nil
        mask.strokeColor = NSColor.black.cgColor
        mask.lineWidth = lineWidth
        layer.addSublayer(disc)
        layer.mask = mask
    }

    func layout(in bounds: CGRect, shape: CGRect, cornerRadius: CGFloat) {
        layer.frame = bounds
        mask.frame = layer.bounds
        mask.path = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .inset(by: lineWidth / 2)
            .path(in: shape)
            .cgPath
        let side = max(shape.width, shape.height) * 1.5
        disc.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        disc.position = CGPoint(x: shape.midX, y: shape.midY)
    }

    func turn() {
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = -2 * Double.pi
        turn.duration = 3
        turn.repeatCount = .infinity
        turn.isRemovedOnCompletion = false
        disc.add(turn, forKey: "turn")
    }
}
