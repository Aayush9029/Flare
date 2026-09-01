import AppKit
import Markdown

/// Turns Markdown source into attributed text and tables. Runs off the main
/// thread; everything it makes is immutable once returned.
struct MarkdownDocumentBuilder {
    let theme: MarkdownTheme
    let isDark: Bool

    struct Output {
        let segments: [MarkdownSegment]
        let pendingHighlights: [CodeHighlighter.Key]
    }

    func build(_ markdown: String) -> Output {
        var state = State(theme: theme, isDark: isDark)
        let document = Document(parsing: markdown, options: [])
        for child in document.children {
            if let table = child as? Table {
                state.flushText()
                state.segments.append(.table(index: state.segments.count, state.table(table)))
            } else {
                state.appendBlock(child, context: .top)
            }
        }
        state.flushText()
        return Output(segments: state.segments, pendingHighlights: state.pendingHighlights)
    }
}

private struct BlockContext {
    var indent: CGFloat = 0
    var inQuote = false
    var isFirstBlock = true

    static let top = BlockContext()
}

private struct InlineStyle {
    var bold = false
    var italic = false
    var strikethrough = false
    var color: NSColor
    var size: CGFloat
}

private struct State {
    let theme: MarkdownTheme
    let isDark: Bool
    var segments: [MarkdownSegment] = []
    var pendingHighlights: [CodeHighlighter.Key] = []
    private var blocks: [NSAttributedString] = []

    init(theme: MarkdownTheme, isDark: Bool) {
        self.theme = theme
        self.isDark = isDark
    }

    mutating func flushText() {
        guard !blocks.isEmpty else { return }
        let joined = NSMutableAttributedString()
        for (index, block) in blocks.enumerated() {
            if index > 0 { joined.append(NSAttributedString(string: "\n")) }
            joined.append(block)
        }
        segments.append(.text(index: segments.count, joined))
        blocks.removeAll()
    }

    // MARK: Blocks

    mutating func appendBlock(_ markup: Markup, context: BlockContext) {
        switch markup {
        case let paragraph as Paragraph:
            blocks.append(marked(styled(inlines(paragraph.children, base: baseStyle(context)), paragraph: paragraphStyle(context: context, spacingAfter: theme.blockSpacing)), context))
        case let heading as Heading:
            var style = baseStyle(context)
            style.size = theme.heading(level: heading.level).pointSize
            style.bold = true
            let text = inlines(heading.children, base: style)
            let paragraph = paragraphStyle(context: context, spacingAfter: theme.blockSpacing * 0.6)
            paragraph.paragraphSpacingBefore = context.isFirstBlock ? 0 : 4
            blocks.append(marked(styled(text, paragraph: paragraph), context))
        case let code as CodeBlock:
            blocks.append(codeBlock(code, context: context))
        case let quote as BlockQuote:
            var inner = context
            inner.indent += 14
            inner.inQuote = true
            var first = true
            for child in quote.children {
                inner.isFirstBlock = first
                appendBlock(child, context: inner)
                first = false
            }
        case let list as UnorderedList:
            appendList(items: Array(list.listItems), ordered: false, start: 1, context: context)
        case let list as OrderedList:
            appendList(items: Array(list.listItems), ordered: true, start: Int(list.startIndex), context: context)
        case is ThematicBreak:
            let paragraph = paragraphStyle(context: context, spacingAfter: theme.blockSpacing)
            paragraph.minimumLineHeight = 10
            paragraph.maximumLineHeight = 10
            let rule = NSMutableAttributedString(string: "\u{00A0}", attributes: [.font: theme.body, .paragraphStyle: paragraph, .markdownBlock: MarkdownBlockAttribute.rule])
            blocks.append(rule)
        case let html as HTMLBlock:
            blocks.append(marked(styled(NSAttributedString(string: html.rawHTML.trimmingCharacters(in: .newlines), attributes: baseAttributes(baseStyle(context))), paragraph: paragraphStyle(context: context, spacingAfter: theme.blockSpacing)), context))
        case let table as Table:
            blocks.append(styled(NSAttributedString(string: table.format(), attributes: [.font: theme.code, .foregroundColor: theme.textColor]), paragraph: paragraphStyle(context: context, spacingAfter: theme.blockSpacing)))
        default:
            let text = inlines(markup.children, base: baseStyle(context))
            if text.length > 0 {
                blocks.append(marked(styled(text, paragraph: paragraphStyle(context: context, spacingAfter: theme.blockSpacing)), context))
            }
        }
    }

    /// Inside a quote the fragment draws a bar, keyed by the block attribute.
    private func marked(_ block: NSAttributedString, _ context: BlockContext) -> NSAttributedString {
        guard context.inQuote else { return block }
        let result = NSMutableAttributedString(attributedString: block)
        result.addAttribute(.markdownBlock, value: MarkdownBlockAttribute.quote, range: NSRange(location: 0, length: result.length))
        return result
    }

    private mutating func appendList(items: [ListItem], ordered: Bool, start: Int, context: BlockContext) {
        let markerWidth: CGFloat = ordered ? 22 : 16
        for (offset, item) in items.enumerated() {
            let marker: String
            if let checkbox = item.checkbox {
                marker = checkbox == .checked ? "☑" : "☐"
            } else {
                marker = ordered ? "\(start + offset)." : "•"
            }
            var inner = context
            inner.indent += markerWidth
            let isLast = offset == items.count - 1
            var firstChild = true
            let children = Array(item.children)
            if children.isEmpty {
                blocks.append(listLine(marker: marker, text: NSAttributedString(), context: context, markerWidth: markerWidth, spacingAfter: isLast ? theme.blockSpacing : 3))
            }
            for (childOffset, child) in children.enumerated() {
                let lastChild = childOffset == children.count - 1
                let spacing: CGFloat = lastChild ? (isLast ? theme.blockSpacing : 3) : 3
                if firstChild, let paragraph = child as? Paragraph {
                    blocks.append(marked(listLine(marker: marker, text: inlines(paragraph.children, base: baseStyle(context)), context: context, markerWidth: markerWidth, spacingAfter: spacing), context))
                } else if firstChild {
                    blocks.append(listLine(marker: marker, text: NSAttributedString(), context: context, markerWidth: markerWidth, spacingAfter: 2))
                    var nested = inner
                    nested.isFirstBlock = false
                    appendBlock(child, context: nested)
                } else {
                    var nested = inner
                    nested.isFirstBlock = false
                    if let paragraph = child as? Paragraph {
                        blocks.append(marked(styled(inlines(paragraph.children, base: baseStyle(context)), paragraph: paragraphStyle(context: nested, spacingAfter: spacing)), context))
                    } else {
                        appendBlock(child, context: nested)
                    }
                }
                firstChild = false
            }
        }
    }

    private func listLine(marker: String, text: NSAttributedString, context: BlockContext, markerWidth: CGFloat, spacingAfter: CGFloat) -> NSAttributedString {
        let paragraph = paragraphStyle(context: context, spacingAfter: spacingAfter)
        paragraph.firstLineHeadIndent = context.indent
        paragraph.headIndent = context.indent + markerWidth
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: context.indent + markerWidth)]
        paragraph.defaultTabInterval = markerWidth
        let line = NSMutableAttributedString(string: marker + "\t", attributes: [.font: theme.body, .foregroundColor: theme.secondaryColor])
        line.append(text)
        line.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: line.length))
        return line
    }

    private mutating func codeBlock(_ code: CodeBlock, context: BlockContext) -> NSAttributedString {
        let language = (code.language ?? "").trimmingCharacters(in: .whitespaces)
        var source = code.code
        if source.hasSuffix("\n") { source.removeLast() }
        let key = CodeHighlighter.Key(code: source, language: language, isDark: isDark)
        let body: NSMutableAttributedString
        if let highlighted = CodeHighlighter.shared.cached(key) {
            body = NSMutableAttributedString(attributedString: highlighted)
        } else {
            if isClosed(code) { pendingHighlights.append(key) }
            body = NSMutableAttributedString(string: source, attributes: [.foregroundColor: theme.textColor])
        }
        let full = NSRange(location: 0, length: body.length)
        body.addAttribute(.font, value: theme.code, range: full)
        body.removeAttribute(.backgroundColor, range: full)
        body.removeAttribute(.link, range: full)

        let lines = paragraphRanges(in: body.string)
        for (index, range) in lines.enumerated() {
            let position: MarkdownBlockAttribute.CodePosition
            switch (index == 0, index == lines.count - 1) {
            case (true, true): position = .only
            case (true, false): position = .first
            case (false, true): position = .last
            case (false, false): position = .middle
            }
            let paragraph = paragraphStyle(context: context, spacingAfter: 0)
            paragraph.lineSpacing = 2
            paragraph.firstLineHeadIndent = context.indent + 12
            paragraph.headIndent = context.indent + 12
            paragraph.tailIndent = -12
            paragraph.lineBreakMode = .byCharWrapping
            if index == 0 { paragraph.paragraphSpacingBefore = 9 }
            if index == lines.count - 1 { paragraph.paragraphSpacing = 9 + theme.blockSpacing }
            body.addAttributes([
                .paragraphStyle: paragraph,
                .markdownBlock: MarkdownBlockAttribute.code(position, language: language),
            ], range: range)
        }
        return body
    }

    /// A fence is closed once the source after it holds the closing line, so a block
    /// still being typed is not highlighted on every keystroke.
    private func isClosed(_ code: CodeBlock) -> Bool {
        guard let range = code.range else { return true }
        return range.upperBound.line > range.lowerBound.line + 1 && code.code.hasSuffix("\n")
    }

    // MARK: Inlines

    private var baseStyle: InlineStyle {
        InlineStyle(color: theme.textColor, size: theme.bodySize)
    }

    private func baseStyle(_ context: BlockContext) -> InlineStyle {
        InlineStyle(color: context.inQuote ? theme.secondaryColor : theme.textColor, size: theme.bodySize)
    }

    private func inlines(_ children: MarkupChildren, base: InlineStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in children { result.append(inline(child, style: base)) }
        return result
    }

    private func inline(_ markup: Markup, style: InlineStyle) -> NSAttributedString {
        switch markup {
        case let text as Markdown.Text:
            return NSAttributedString(string: text.string, attributes: baseAttributes(style))
        case is SoftBreak:
            return NSAttributedString(string: " ", attributes: baseAttributes(style))
        case is LineBreak:
            return NSAttributedString(string: "\u{2028}", attributes: baseAttributes(style))
        case let emphasis as Emphasis:
            var inner = style; inner.italic = true
            return inlines(emphasis.children, base: inner)
        case let strong as Strong:
            var inner = style; inner.bold = true
            return inlines(strong.children, base: inner)
        case let strike as Strikethrough:
            var inner = style; inner.strikethrough = true
            return inlines(strike.children, base: inner)
        case let code as InlineCode:
            return NSAttributedString(string: code.code, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: style.size - 1, weight: .regular),
                .foregroundColor: style.color,
                .backgroundColor: MarkdownTheme.inlineCodeBackground,
            ])
        case let link as Markdown.Link:
            let text = inlines(link.children, base: style)
            let result = NSMutableAttributedString(attributedString: text)
            if let destination = link.destination, let url = URL(string: destination) {
                result.addAttributes([.link: url, .foregroundColor: theme.linkColor], range: NSRange(location: 0, length: result.length))
            }
            return result
        case let image as Markdown.Image:
            return imageAttachment(image, style: style)
        case let html as InlineHTML:
            return NSAttributedString(string: html.rawHTML, attributes: baseAttributes(style))
        case let symbol as SymbolLink:
            return NSAttributedString(string: symbol.destination ?? "", attributes: baseAttributes(style))
        default:
            return inlines(markup.children, base: style)
        }
    }

    private func imageAttachment(_ image: Markdown.Image, style: InlineStyle) -> NSAttributedString {
        guard let source = image.source, let url = URL(string: source) else {
            return NSAttributedString(string: image.plainText, attributes: baseAttributes(style))
        }
        let attachment = MarkdownImageAttachment.shared(for: url)
        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttributes([.font: theme.body, .foregroundColor: style.color], range: NSRange(location: 0, length: result.length))
        return result
    }

    private func baseAttributes(_ style: InlineStyle) -> [NSAttributedString.Key: Any] {
        var font: NSFont = style.bold
            ? .systemFont(ofSize: style.size, weight: .semibold)
            : .systemFont(ofSize: style.size)
        if style.italic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: style.color]
        if style.strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return attributes
    }

    // MARK: Paragraph styles

    private func paragraphStyle(context: BlockContext, spacingAfter: CGFloat) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = theme.lineSpacing
        style.paragraphSpacing = spacingAfter
        style.firstLineHeadIndent = context.indent
        style.headIndent = context.indent
        style.lineBreakMode = .byWordWrapping
        return style
    }

    private func styled(_ text: NSAttributedString, paragraph: NSParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
        return result
    }

    // MARK: Tables

    func table(_ table: Table) -> MarkdownTable {
        let alignments = table.columnAlignments
        func cells(_ cells: some Sequence<Table.Cell>) -> [MarkdownTable.Cell] {
            cells.enumerated().map { index, cell in
                let text = inlines(cell.children, base: baseStyle)
                let alignment: NSTextAlignment = switch alignments[safe: index] ?? nil {
                case .center: .center
                case .right: .right
                default: .left
                }
                return MarkdownTable.Cell(text: AttributedString(text), alignment: alignment)
            }
        }
        return MarkdownTable(
            header: cells(table.head.cells),
            rows: table.body.rows.map { cells($0.cells) }
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Byte ranges of each line, split on newlines, for per-line paragraph attributes.
func paragraphRanges(in string: String) -> [NSRange] {
    let ns = string as NSString
    var ranges: [NSRange] = []
    var location = 0
    while location <= ns.length {
        let lineEnd = ns.range(of: "\n", range: NSRange(location: location, length: ns.length - location))
        if lineEnd.location == NSNotFound {
            ranges.append(NSRange(location: location, length: ns.length - location))
            break
        }
        ranges.append(NSRange(location: location, length: lineEnd.location + 1 - location))
        location = lineEnd.location + 1
    }
    return ranges
}
