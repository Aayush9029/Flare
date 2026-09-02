import FlareKit
import SwiftUI

/// The queue above the composer. The glass rows carry their own surface; any band
/// beneath them read as a smear. The chat underneath does not move.
struct QueueOverlay: View {
    let model: FlareModel
    let composerHeight: CGFloat
    @Binding var queueHeight: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            QueueView(model: model)
                .padding(.horizontal, 16)
                .padding(.bottom, composerHeight)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { queueHeight = $0 }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
