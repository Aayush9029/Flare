import AppKit
import SwiftUI

/// A small wallpaper thumbnail behind the panel miniatures. Photo by Unsplash.
enum DesktopWallpaper {
    static let image: Image = {
        guard let url = Bundle.main.url(forResource: "desktop", withExtension: "jpg"),
              let nsImage = NSImage(contentsOf: url)
        else { return Image(systemName: "photo") }
        return Image(nsImage: nsImage)
    }()
}
