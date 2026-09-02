import FlareKit
import SwiftUI

/// A desktop in miniature with the panel where, and as tall as, a choice puts it.
struct PanelPositionIllustration: View {
    var position: PanelPosition = .bottomRight
    var size: PanelSize = .compact
    var width: CGFloat = PanelSize.defaultWidth

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.size
            let menuBar = screen.height * 0.07
            let inset = screen.width * 0.05
            let panel = CGSize(width: screen.width * panelWidthShare, height: panelHeight(screen: screen, menuBar: menuBar, inset: inset))
            ZStack(alignment: .topLeading) {
                DesktopWallpaper.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.width, height: screen.height)
                    .clipped()
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: menuBar)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.85))
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(.black.opacity(0.12))
                            .frame(height: 6)
                            .padding(panel.width * 0.1)
                    }
                    .frame(width: panel.width, height: panel.height)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .offset(origin(screen: screen, menuBar: menuBar, panel: panel, inset: inset))
            }
        }
    }

    /// 420 points reads as a fifth of the screen, 720 as a third.
    private var panelWidthShare: CGFloat {
        let narrow = PanelSize.widths.first ?? 420
        let wide = PanelSize.widths.last ?? 720
        let t = min(max((width - narrow) / (wide - narrow), 0), 1)
        return 0.18 + t * 0.14
    }

    private func panelHeight(screen: CGSize, menuBar: CGFloat, inset: CGFloat) -> CGFloat {
        let usable = screen.height - menuBar - inset * 2
        return switch size {
        case .compact: usable * 0.5
        case .half: usable * 0.66
        case .full: usable
        }
    }

    private func origin(screen: CGSize, menuBar: CGFloat, panel: CGSize, inset: CGFloat) -> CGSize {
        let bottom = screen.height - panel.height - inset
        return switch position {
        case .bottomLeft:
            CGSize(width: inset, height: bottom)
        case .bottomRight:
            CGSize(width: screen.width - panel.width - inset, height: bottom)
        case .center:
            CGSize(width: (screen.width - panel.width) / 2, height: menuBar + (screen.height - menuBar - panel.height) / 2)
        }
    }
}
