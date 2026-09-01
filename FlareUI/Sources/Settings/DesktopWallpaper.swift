import AppKit
import SwiftUI

/// Small wallpaper thumbnails behind the panel miniatures, one per appearance.
/// Photos from Unsplash, scaled down to the size they are drawn at.
enum DesktopWallpaper {
    static let light = load("desktop-light")
    static let dark = load("desktop-dark")

    static func image(for scheme: ColorScheme) -> Image {
        scheme == .dark ? dark : light
    }

    private static func load(_ name: String) -> Image {
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let nsImage = NSImage(contentsOf: url)
        else { return Image(systemName: "photo") }
        return Image(nsImage: nsImage)
    }
}
