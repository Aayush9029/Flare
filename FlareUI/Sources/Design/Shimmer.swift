import SwiftUI

/// A highlight that sweeps across the content, then rests before the next pass.
struct Shimmer: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let period: TimeInterval = 2.0
    private let sweep: TimeInterval = 1.1

    func body(content: Content) -> some View {
        content.overlay {
            if isActive, !reduceMotion {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
                    let progress = min(elapsed / sweep, 1)
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.9), location: 0.5),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width)
                        .offset(x: -width + progress * 2 * width)
                    }
                }
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
