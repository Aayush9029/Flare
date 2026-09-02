import AppKit
import SwiftUI

/// A provider's brand mark from the bundled LobeHub set, tinted like text, or the
/// kind's symbol when there is none.
struct ProviderGlyph: View {
    let icon: String?
    let symbol: String
    var size: CGFloat = 12

    var body: some View {
        if let icon, let image = NSImage(named: "provider-\(icon)") {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .frame(width: size, height: size)
        }
    }
}
