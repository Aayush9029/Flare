import SwiftUI

/// A hue that travels around the composer while a response streams.
struct StreamingBorder: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat

    private let colors: [Color] = [
        Color(red: 0.66, green: 0.48, blue: 1.00),
        Color(red: 0.48, green: 0.25, blue: 0.89),
        Color(red: 0.29, green: 0.12, blue: 0.66),
        Color(red: 0.66, green: 0.48, blue: 1.00),
    ]

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    TimelineView(.animation) { timeline in
                        let angle = Angle.degrees(
                            timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3 * 360
                        )
                        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        let gradient = AngularGradient(colors: colors, center: .center, angle: angle)

                        shape
                            .strokeBorder(gradient, lineWidth: 2)
                            .overlay {
                                // A blurred copy of the same stroke reads as a glow
                                // without a second animation to keep in step.
                                shape
                                    .strokeBorder(gradient, lineWidth: 4)
                                    .blur(radius: 7)
                                    .opacity(0.7)
                            }
                    }
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
