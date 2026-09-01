import AppKit

/// Fonts, colours and spacing for rendered Markdown. Colours are dynamic so a
/// built string survives an appearance change without a rebuild.
struct MarkdownTheme: @unchecked Sendable {
    let bodySize: CGFloat
    let lineSpacing: CGFloat
    let blockSpacing: CGFloat
    let textColor: NSColor
    let codeSize: CGFloat
    /// Reasoning summaries title their sections with a bold line of their own.
    /// Grok sets those as headings over the muted lines beneath; so does this.
    var boldLinesAreTitles = false

    static let answer = MarkdownTheme(bodySize: 13.5, lineSpacing: 4.5, blockSpacing: 10, textColor: .labelColor, codeSize: 12.5)
    static let reasoning = MarkdownTheme(bodySize: 12, lineSpacing: 3, blockSpacing: 6, textColor: .secondaryLabelColor, codeSize: 11.5, boldLinesAreTitles: true)
    /// Reasoning read on its own, across the panel: answer-sized, still muted.
    static let thoughts = MarkdownTheme(bodySize: 13, lineSpacing: 4, blockSpacing: 8, textColor: .secondaryLabelColor, codeSize: 12, boldLinesAreTitles: true)

    var body: NSFont { .systemFont(ofSize: bodySize) }
    var bold: NSFont { .systemFont(ofSize: bodySize, weight: .semibold) }
    var code: NSFont { .monospacedSystemFont(ofSize: codeSize, weight: .regular) }
    var secondaryColor: NSColor { .secondaryLabelColor }
    var linkColor: NSColor { .linkColor }

    func heading(level: Int) -> NSFont {
        switch level {
        case 1: .systemFont(ofSize: bodySize + 5.5, weight: .semibold)
        case 2: .systemFont(ofSize: bodySize + 3.5, weight: .semibold)
        case 3: .systemFont(ofSize: bodySize + 2, weight: .semibold)
        default: bold
        }
    }

    static let codeBackground = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor.white.withAlphaComponent(0.07) : NSColor.black.withAlphaComponent(0.05)
    }
    static let inlineCodeBackground = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.07)
    }
    static let rule = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor.white.withAlphaComponent(0.16) : NSColor.black.withAlphaComponent(0.12)
    }
}

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}
