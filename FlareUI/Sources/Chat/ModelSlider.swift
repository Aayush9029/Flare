import FlareKit
import SwiftUI

/// Five stops from Instant to Pro on one track, after ChatGPT's picker. Dragging
/// moves the knob freely; letting go snaps it to the nearest stop and sets both
/// the model and the effort at once.
struct ModelSlider: View {
    @Bindable var preferences: Preferences
    /// The stop under the knob while a drag is in progress, for the label above.
    var onPreview: (ModelLevel?) -> Void = { _ in }

    @State private var dragValue: Double?

    private let levels = ModelLevel.allCases
    private let height: CGFloat = 44
    private let knob: CGFloat = 30

    private var settled: Double {
        Double(ModelLevel.matching(model: preferences.selectedModel, effort: preferences.effectiveEffort)?.rawValue ?? ModelLevel.medium.rawValue)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let inset = height / 2
            let span = width - inset * 2
            let last = Double(levels.count - 1)
            let value = dragValue ?? settled
            let knobX = inset + span * CGFloat(value / last)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.10))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.62, green: 0.44, blue: 1.0), Color(red: 0.50, green: 0.30, blue: 0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: knobX + inset)
                ForEach(levels) { level in
                    Circle()
                        .fill(.white.opacity(Double(level.rawValue) <= value ? 0.55 : 0.35))
                        .frame(width: 6, height: 6)
                        .position(x: inset + span * CGFloat(Double(level.rawValue) / last), y: height / 2)
                }
                Circle()
                    .fill(.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .position(x: knobX, y: height / 2)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let raw = Double((gesture.location.x - inset) / span) * last
                        let clamped = min(max(raw, 0), last)
                        dragValue = clamped
                        onPreview(levels[Int(clamped.rounded())])
                    }
                    .onEnded { gesture in
                        let raw = Double((gesture.location.x - inset) / span) * last
                        let level = levels[Int(min(max(raw, 0), last).rounded())]
                        preferences.$selectedModel.withLock { $0 = level.model }
                        preferences.$reasoningEffort.withLock { $0 = level.effort }
                        withAnimation(.snappy(duration: 0.28)) { dragValue = nil }
                        onPreview(nil)
                    }
            )
        }
        .frame(height: height)
        .animation(.snappy(duration: 0.28), value: settled)
        .accessibilityElement()
        .accessibilityLabel("Intelligence")
        .accessibilityValue(ModelLevel.matching(model: preferences.selectedModel, effort: preferences.effectiveEffort)?.title ?? preferences.model.displayName)
    }
}
