import AppKit

/// Marks paragraphs whose chrome the layout fragment draws: code boxes, quote bars, rules.
enum MarkdownBlockAttribute: Equatable {
    enum CodePosition { case only, first, middle, last }

    case code(CodePosition, language: String)
    case quote
    case rule
}

extension NSAttributedString.Key {
    static let markdownBlock = NSAttributedString.Key("flare.markdownBlock")
}
