import AppKit

/// Draws the chrome behind a marked paragraph: the box around code, the bar beside
/// a quote, the line of a rule. Text is drawn by the superclass afterwards.
///
/// Drawing coordinates are relative to the fragment's own origin, which sits at the
/// paragraph's head indent, not at the container edge. `containerLeft` undoes that.
final class MarkdownLayoutFragment: NSTextLayoutFragment {
    private let block: MarkdownBlockAttribute
    private static let padding: CGFloat = 9

    init(textElement: NSTextElement, range: NSTextRange?, block: MarkdownBlockAttribute) {
        self.block = block
        super.init(textElement: textElement, range: range)
    }

    required init?(coder: NSCoder) { nil }

    /// Read at draw time: a fragment outlives container resizes.
    private var containerWidth: CGFloat {
        textLayoutManager?.textContainer?.size.width ?? layoutFragmentFrame.width
    }

    override var renderingSurfaceBounds: CGRect {
        super.renderingSurfaceBounds.union(
            CGRect(x: -layoutFragmentFrame.minX, y: -Self.padding, width: containerWidth, height: layoutFragmentFrame.height + Self.padding * 2)
        )
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        let containerLeft = point.x - layoutFragmentFrame.minX
        let lines = lineBounds
        context.saveGState()
        switch block {
        case .code(let position, let language):
            drawCodeBox(position: position, language: language, left: containerLeft, top: point.y + lines.minY, height: lines.height, in: context)
        case .quote:
            context.setFillColor(MarkdownTheme.rule.cgColor)
            context.fill(CGRect(x: containerLeft + 2, y: point.y + lines.minY, width: 3, height: lines.height))
        case .rule:
            context.setFillColor(MarkdownTheme.rule.cgColor)
            context.fill(CGRect(x: containerLeft, y: point.y + lines.midY, width: containerWidth, height: 1))
        }
        context.restoreGState()
        super.draw(at: point, in: context)
    }

    private var lineBounds: CGRect {
        textLineFragments.reduce(CGRect.null) { $0.union($1.typographicBounds) }
    }

    private func drawCodeBox(position: MarkdownBlockAttribute.CodePosition, language: String, left: CGFloat, top: CGFloat, height: CGFloat, in context: CGContext) {
        var box = CGRect(x: left, y: top, width: containerWidth, height: height)
        switch position {
        case .only:
            box = box.insetBy(dx: 0, dy: -Self.padding)
        case .first:
            box.origin.y -= Self.padding
            box.size.height += Self.padding + 2
        case .middle:
            box.size.height += 2
        case .last:
            box.size.height += Self.padding
        }
        let radius: CGFloat = 8
        let topRadius: CGFloat = (position == .only || position == .first) ? radius : 0
        let bottomRadius: CGFloat = (position == .only || position == .last) ? radius : 0
        let path = CGMutablePath()
        path.move(to: CGPoint(x: box.minX, y: box.minY + topRadius))
        path.addArc(tangent1End: CGPoint(x: box.minX, y: box.minY), tangent2End: CGPoint(x: box.minX + topRadius, y: box.minY), radius: topRadius)
        path.addArc(tangent1End: CGPoint(x: box.maxX, y: box.minY), tangent2End: CGPoint(x: box.maxX, y: box.minY + topRadius), radius: topRadius)
        path.addArc(tangent1End: CGPoint(x: box.maxX, y: box.maxY), tangent2End: CGPoint(x: box.maxX - bottomRadius, y: box.maxY), radius: bottomRadius)
        path.addArc(tangent1End: CGPoint(x: box.minX, y: box.maxY), tangent2End: CGPoint(x: box.minX, y: box.maxY - bottomRadius), radius: bottomRadius)
        path.closeSubpath()
        context.setFillColor(MarkdownTheme.codeBackground.cgColor)
        context.addPath(path)
        context.fillPath()

        if position == .first || position == .only, !language.isEmpty {
            let label = NSAttributedString(string: language, attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ])
            let size = label.size()
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
            label.draw(at: CGPoint(x: box.maxX - size.width - 10, y: box.minY + 4))
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
