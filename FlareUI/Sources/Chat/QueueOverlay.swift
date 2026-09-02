import FlareKit
import SwiftUI

/// The queue above the composer, on a band of material that frosts the chat from
/// the bottom up, the way the picker does. The chat underneath does not move.
struct QueueOverlay: View {
    let model: FlareModel
    let composerHeight: CGFloat

    @State private var queueHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.regularMaterial)
                .frame(height: queueHeight + 72)
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
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
