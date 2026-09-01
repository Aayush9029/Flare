import SwiftUI

struct MarkdownTextRepresentable: NSViewRepresentable {
    let text: NSAttributedString
    let markdownSource: () -> String

    func makeNSView(context: Context) -> MarkdownTextView {
        let view = MarkdownTextView()
        view.markdownSource = markdownSource
        view.setAttributedText(text)
        return view
    }

    func updateNSView(_ view: MarkdownTextView, context: Context) {
        view.markdownSource = markdownSource
        view.setAttributedText(text)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MarkdownTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else { return nil }
        return CGSize(width: width, height: nsView.height(fittingWidth: width))
    }
}
