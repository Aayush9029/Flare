import FlareKit
import SwiftUI

/// A desktop in miniature with the panel where that choice puts it.
struct PanelPositionIllustration: View {
    let position: PanelPosition

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let panel = CGSize(width: size.width * 0.28, height: size.height * 0.52)
            let inset: CGFloat = size.width * 0.06
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color(red: 0.20, green: 0.16, blue: 0.36), Color(red: 0.07, green: 0.05, blue: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: size.height * 0.07)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.85))
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(.black.opacity(0.12))
                            .frame(height: panel.height * 0.16)
                            .padding(panel.width * 0.1)
                    }
                    .frame(width: panel.width, height: panel.height)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .offset(origin(in: size, panel: panel, inset: inset))
            }
        }
    }

    private func origin(in size: CGSize, panel: CGSize, inset: CGFloat) -> CGSize {
        switch position {
        case .bottomLeft:
            CGSize(width: inset, height: size.height - panel.height - inset)
        case .bottomRight:
            CGSize(width: size.width - panel.width - inset, height: size.height - panel.height - inset)
        case .center:
            CGSize(width: (size.width - panel.width) / 2, height: (size.height - panel.height) / 2)
        }
    }
}
