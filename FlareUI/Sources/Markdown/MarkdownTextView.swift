import AppKit

/// One TextKit 2 text view for a whole message. New text replaces only the tail
/// that changed, so a streaming answer lays out a few lines per update, not all
/// of them.
final class MarkdownTextView: NSTextView, @preconcurrency NSTextLayoutManagerDelegate {
    var markdownSource: () -> String = { "" }

    private var currentText = NSAttributedString()
    private var version = 0
    private var measured: (width: CGFloat, version: Int, height: CGFloat)?

    convenience init() {
        self.init(usingTextLayoutManager: true)
        isEditable = false
        isSelectable = true
        isRichText = true
        drawsBackground = false
        textContainerInset = .zero
        textContainer?.lineFragmentPadding = 0
        // SwiftUI sizes the view from `height(fittingWidth:)`. Left to itself, the
        // text view would reset the container on every frame change, which throws
        // away the layout of every fragment, and redraw everything on every resize.
        textContainer?.widthTracksTextView = false
        textContainer?.heightTracksTextView = false
        isVerticallyResizable = false
        isHorizontallyResizable = false
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .topLeft
        linkTextAttributes = [.foregroundColor: NSColor.linkColor, .cursor: NSCursor.pointingHand]
        textLayoutManager?.delegate = self
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    // MARK: Content

    func setAttributedText(_ text: NSAttributedString) {
        guard let storage = textStorage else { return }
        let shared = commonPrefixLength(currentText, text)
        guard shared < currentText.length || shared < text.length else { return }
        // From the start of the paragraph that holds the first change.
        let newline = (CFAttributedStringGetString(text) as NSString)
            .range(of: "\n", options: .backwards, range: NSRange(location: 0, length: shared))
        let start = newline.location == NSNotFound ? 0 : NSMaxRange(newline)

        storage.beginEditing()
        storage.replaceCharacters(
            in: NSRange(location: start, length: currentText.length - start),
            with: text.attributedSubstring(from: NSRange(location: start, length: text.length - start))
        )
        storage.endEditing()
        currentText = text
        version += 1
        measured = nil
        redisplayFrom = start
    }

    /// TextKit invalidates only the line rects of edited paragraphs, which is
    /// narrower than the boxes and labels the fragments draw around them.
    private var redisplayFrom: Int?

    private func redisplayIfNeeded() {
        guard let start = redisplayFrom, let layoutManager = textLayoutManager,
              let contentStorage = layoutManager.textContentManager as? NSTextContentStorage
        else { return }
        redisplayFrom = nil
        let location = contentStorage.location(contentStorage.documentRange.location, offsetBy: min(start, currentText.length))
        let top = location.flatMap { layoutManager.textLayoutFragment(for: $0)?.layoutFragmentFrame.minY } ?? 0
        setNeedsDisplay(CGRect(x: 0, y: max(top - 16, 0), width: bounds.width, height: max(bounds.height, measured?.height ?? 0)))
    }

    /// Measured only at the width SwiftUI proposes. Any other width would resize the
    /// container and throw away the layout of every fragment, not just the new tail.
    func height(fittingWidth width: CGFloat) -> CGFloat {
        if let measured, measured.width == width, measured.version == version { return measured.height }
        guard let container = textContainer, let layoutManager = textLayoutManager else { return 0 }
        if abs(container.size.width - width) > 0.5 {
            container.size = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        let height = ceil(layoutManager.usageBoundsForTextContainer.height)
        measured = (width, version, height)
        redisplayIfNeeded()
        return height
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    // MARK: Fragments

    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: any NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {
        guard let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage,
              let text = contentStorage.attributedString
        else { return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange) }
        let offset = contentStorage.offset(from: contentStorage.documentRange.location, to: location)
        guard offset < text.length,
              let block = text.attribute(.markdownBlock, at: offset, effectiveRange: nil) as? MarkdownBlockAttribute
        else { return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange) }
        return MarkdownLayoutFragment(textElement: textElement, range: textElement.elementRange, block: block)
    }

    // MARK: Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let hasSelection = selectedRange().length > 0
        menu.addItem(withTitle: hasSelection ? "Copy" : "Copy Text", action: #selector(copyPlain), keyEquivalent: "")
        menu.addItem(withTitle: "Copy as Markdown", action: #selector(copyMarkdown), keyEquivalent: "")
        let point = convert(event.locationInWindow, from: nil)
        if let code = codeBlock(at: point) {
            let item = NSMenuItem(title: "Copy Code", action: #selector(copyCode(_:)), keyEquivalent: "")
            item.representedObject = code
            menu.addItem(item)
        }
        for item in menu.items { item.target = self }
        return menu
    }

    @objc private func copyPlain() {
        let range = selectedRange().length > 0 ? selectedRange() : NSRange(location: 0, length: currentText.length)
        put(currentText.attributedSubstring(from: range).string)
    }

    @objc private func copyMarkdown() {
        put(markdownSource())
    }

    @objc private func copyCode(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String { put(code) }
    }

    private func put(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func codeBlock(at point: NSPoint) -> String? {
        let index = characterIndexForInsertion(at: point)
        guard index < currentText.length,
              case .code? = currentText.attribute(.markdownBlock, at: index, effectiveRange: nil) as? MarkdownBlockAttribute
        else { return nil }
        var start = index
        var end = index
        let string = currentText.string as NSString
        func isCode(_ i: Int) -> Bool {
            guard i >= 0, i < currentText.length else { return false }
            if case .code? = currentText.attribute(.markdownBlock, at: i, effectiveRange: nil) as? MarkdownBlockAttribute { return true }
            return false
        }
        while isCode(start - 1) { start -= 1 }
        while isCode(end + 1) { end += 1 }
        return string.substring(with: NSRange(location: start, length: end - start + 1))
            .trimmingCharacters(in: .newlines)
    }
}

/// How many UTF-16 units two attributed strings share from the start, in characters and
/// attributes alike. Comparing per paragraph copied both strings into substrings on
/// every update of a streaming answer; Core Foundation reads both in place.
private func commonPrefixLength(_ a: NSAttributedString, _ b: NSAttributedString) -> Int {
    let left = CFAttributedStringGetString(a)
    let right = CFAttributedStringGetString(b)
    let limit = min(CFStringGetLength(left), CFStringGetLength(right))
    var length = 0
    var leftChunk = [UniChar](repeating: 0, count: 256)
    var rightChunk = [UniChar](repeating: 0, count: 256)
    while length < limit {
        let count = min(256, limit - length)
        CFStringGetCharacters(left, CFRange(location: length, length: count), &leftChunk)
        CFStringGetCharacters(right, CFRange(location: length, length: count), &rightChunk)
        var index = 0
        while index < count, leftChunk[index] == rightChunk[index] { index += 1 }
        length += index
        if index < count { break }
    }
    var location = 0
    while location < length {
        var leftRun = CFRange()
        var rightRun = CFRange()
        let leftAttributes = CFAttributedStringGetAttributes(a, location, &leftRun)
        let rightAttributes = CFAttributedStringGetAttributes(b, location, &rightRun)
        guard CFEqual(leftAttributes, rightAttributes) else { return location }
        location = min(leftRun.location + leftRun.length, rightRun.location + rightRun.length)
    }
    return length
}
