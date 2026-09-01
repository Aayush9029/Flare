import AppKit
import SwiftStreamingMarkdown
import SwiftUI

enum MarkdownStyle {
    /// The package default keeps its dark code styling in both appearances and
    /// sizes body text for a full-width chat; a 470 pt panel wants less of both.
    static let config = MarkdownRenderConfig(
        headingStyle: headingStyle,
        paragraphStyle: MarkdownRenderConfig.MarkdownTextStyle(textFonts: body, textColor: .primary),
        inlineStyle: inlineStyle,
        codeBlockConfig: CodeBlockConfig(theme: .xcode, backgroundColor: Color.primary.opacity(0.06)),
        blockSpacing: 10,
        imageConfig: ImageConfig(
            enabled: true,
            allowedImageTypes: [.remote(allowedDomains: [])]
        )
    )

    /// Reasoning summaries sit under the answer in a quieter, smaller voice.
    static let reasoningConfig = MarkdownRenderConfig(
        headingStyle: headingStyle,
        paragraphStyle: MarkdownRenderConfig.MarkdownTextStyle(textFonts: fonts(size: 12, lineHeight: 17), textColor: .secondary),
        inlineStyle: inlineStyle,
        codeBlockConfig: CodeBlockConfig(theme: .xcode, backgroundColor: Color.primary.opacity(0.06)),
        blockSpacing: 6
    )

    private static let body = fonts(size: 13.5, lineHeight: 21)

    /// The package sizes links and inline code from its own typography, which
    /// leaves them noticeably larger than the body text once the body shrinks.
    private static let inlineStyle = MarkdownRenderConfig.MarkdownInlineTextStyle(
        boldTextColor: .primary,
        linkTextFont: NSFont.systemFont(ofSize: 13.5, weight: .regular),
        linkTextColor: .accentColor,
        codeTextFont: .monospacedSystemFont(ofSize: 12.5, weight: .regular),
        codeTextColor: .primary,
        codeBackgroundColor: Color.primary.opacity(0.07),
        codeUnderlineColor: .clear
    )

    private static let headingStyle = MarkdownRenderConfig.MarkdownHeadingTextStyle(
        h1Font: fonts(size: 19, lineHeight: 26),
        h2Font: fonts(size: 17, lineHeight: 24),
        h3Font: fonts(size: 15.5, lineHeight: 22),
        h4Font: body,
        h5Font: body,
        h6Font: body,
        textColor: .primary
    )

    private static func fonts(size: CGFloat, lineHeight: CGFloat) -> TextFonts {
        let manager = NSFontManager.shared
        let regular = NSFont.systemFont(ofSize: size, weight: .regular)
        let bold = NSFont.systemFont(ofSize: size, weight: .semibold)
        return TextFonts(
            normal: regular,
            italic: manager.convert(regular, toHaveTrait: .italicFontMask),
            bold: bold,
            boldItalic: manager.convert(bold, toHaveTrait: .italicFontMask),
            preferredLetterSpacing: 0,
            preferredLineHeight: lineHeight
        )
    }
}
