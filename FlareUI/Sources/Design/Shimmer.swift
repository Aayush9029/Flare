import AppKit
import SwiftUI

/// A highlight that sweeps across the content, then rests before the next pass.
struct Shimmer: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isActive, !reduceMotion {
                ShimmerSweep()
                    .mask(content)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func shimmer(isActive: Bool) -> some View {
        modifier(Shimmer(isActive: isActive))
    }
}

/// Core Animation moves the highlight in the render server. A TimelineView here, with
/// the one in the streaming border, re-rendered the panel on every display frame.
private struct ShimmerSweep: NSViewRepresentable {
    func makeNSView(context: Context) -> ShimmerSweepView { ShimmerSweepView() }
    func updateNSView(_ view: ShimmerSweepView, context: Context) {}
}

private final class ShimmerSweepView: NSView {
    private let highlight = CAGradientLayer()
    private static let period: CFTimeInterval = 2.0
    private static let sweep: CFTimeInterval = 1.1

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        // Clear white, not `.clear`: the layer blends unpremultiplied, and black at zero
        // alpha would grey the sweep's edges.
        let edge = NSColor.white.withAlphaComponent(0).cgColor
        highlight.colors = [edge, NSColor.white.withAlphaComponent(0.9).cgColor, edge]
        highlight.locations = [0, 0.5, 1]
        highlight.startPoint = CGPoint(x: 0, y: 0.5)
        highlight.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.addSublayer(highlight)
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        guard highlight.bounds.size != bounds.size else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.bounds = bounds
        highlight.position = CGPoint(x: bounds.midX - bounds.width, y: bounds.midY)
        CATransaction.commit()
        sweepAcross()
    }

    /// Left of the content to right of it in `sweep` seconds, then out of sight until the period ends.
    private func sweepAcross() {
        let move = CAKeyframeAnimation(keyPath: "position.x")
        move.values = [bounds.midX - bounds.width, bounds.midX + bounds.width, bounds.midX + bounds.width]
        move.keyTimes = [0, NSNumber(value: Self.sweep / Self.period), 1]
        move.duration = Self.period
        move.repeatCount = .infinity
        move.isRemovedOnCompletion = false
        highlight.add(move, forKey: "sweep")
    }
}
