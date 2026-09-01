import AppKit
import UniformTypeIdentifiers

/// Turns dropped or pasted items into image data the API accepts: PNG or JPEG,
/// no longer than 1600 points on a side.
public enum ImageDrop {
    static let maxSide: CGFloat = 1600

    /// Image data on the pasteboard, when it holds images and no text. Text pastes
    /// belong to the text field.
    public static func pasteboardImages(_ pasteboard: NSPasteboard = .general) -> [Data] {
        guard pasteboard.string(forType: .string) == nil else { return [] }
        var images: [Data] = []
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if let file = try? Data(contentsOf: url), let image = NSImage(data: file) {
                    images.append(normalize(image, original: file))
                }
            }
        }
        if images.isEmpty, let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let image = NSImage(data: data) {
            images.append(normalize(image, original: data))
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
                          let file = try? Data(contentsOf: url), let image = NSImage(data: file)
                    else { return }
                    let normalized = normalize(image, original: file)
                    Task { @MainActor in add(normalized) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                accepted = true
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, let image = NSImage(data: data) else { return }
                    let normalized = normalize(image, original: data)
                    Task { @MainActor in add(normalized) }
                }
            }
        }
        return accepted
    }

    /// Keeps PNG and JPEG as they are when small enough; anything else, or anything
    /// large, is re-encoded as JPEG at a size the model can use.
    static func normalize(_ image: NSImage, original: Data) -> Data {
        let head = [UInt8](original.prefix(4))
        let isPNG = head.starts(with: [0x89, 0x50, 0x4E, 0x47])
        let isJPEG = head.starts(with: [0xFF, 0xD8, 0xFF])
        let size = image.size
        if (isPNG || isJPEG), max(size.width, size.height) <= maxSide { return original }

        let scale = min(1, maxSide / max(size.width, size.height, 1))
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(target.width), pixelsHigh: Int(target.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return original }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) ?? original
    }
}
