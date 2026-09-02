import FlareKit
import SwiftUI

/// The queue above the composer, over a soft scrim that deepens toward the
/// composer. The chat underneath does not move.
struct QueueOverlay: View {
    let model: FlareModel
    let composerHeight: CGFloat
    @Binding var queueHeight: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var scrim: Color {
        colorScheme == .dark ? .black.opacity(0.28) : .white.opacity(0.5)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // A soft scrim, not a material: the glass rows carry their own surface, and
            // a blur band under them read as a smear.
            LinearGradient(
                stops: [.init(color: scrim.opacity(0), location: 0), .init(color: scrim, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: queueHeight + 80)
            .padding(.bottom, composerHeight)
            .allowsHitTesting(false)

            QueueView(model: model)
                .padding(.horizontal, 16)
                .padding(.bottom, composerHeight)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { queueHeight = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
