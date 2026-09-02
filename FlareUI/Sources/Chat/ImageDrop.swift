import AppKit
import UniformTypeIdentifiers

/// Turns dropped, pasted or captured images into what goes to the model: JPEG at
/// 80 percent, no longer than 1024 pixels on a side, whatever came in.
public enum ImageDrop {
    static let maxSide: CGFloat = 1024
    static let quality = 0.8

    /// Image data on the pasteboard, when it holds images and no text. Text pastes
    /// belong to the text field.
    public static func pasteboardImages(_ pasteboard: NSPasteboard = .general) -> [Data] {
        guard pasteboard.string(forType: .string) == nil else { return [] }
        var images: [Data] = []
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if let file = try? Data(contentsOf: url), let normalized = normalize(file) {
                    images.append(normalized)
                }
            }
        }
        if images.isEmpty, let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let normalized = normalize(data) {
            images.append(normalized)
        }
        return images
    }

    @MainActor
    static func load(_ providers: [NSItemProvider], into add: @escaping @MainActor (Data) -> Void) -> Bool {
        var accepted = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil),
                          let file = try? Data(contentsOf: url), let normalized = normalize(file)
                    else { return }
                    Task { @MainActor in add(normalized) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                accepted = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, let normalized = normalize(data) else { return }
                    Task { @MainActor in add(normalized) }
                }
            }
        }
        return accepted
    }

    /// Re-encodes any image as JPEG at 80 percent within 1024 pixels, so a Retina
    /// screenshot or a camera photo does not go to the model at full weight.
    public static func normalize(_ original: Data) -> Data? {
        guard let image = NSImage(data: original) else { return nil }
        let pixels = image.representations
            .map { CGSize(width: $0.pixelsWide, height: $0.pixelsHigh) }
            .max { $0.width * $0.height < $1.width * $1.height }
            ?? image.size
        guard pixels.width > 0, pixels.height > 0 else { return nil }
        let scale = min(1, maxSide / max(pixels.width, pixels.height))
        let target = NSSize(width: (pixels.width * scale).rounded(), height: (pixels.height * scale).rounded())
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(target.width), pixelsHigh: Int(target.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        // JPEG has no alpha: transparent pixels would otherwise go black.
        NSColor.white.setFill()
        NSRect(origin: .zero, size: target).fill()
        image.draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}
