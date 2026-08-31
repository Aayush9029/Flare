import Foundation
import SwiftStreamingMarkdown
import Testing

@Suite("Markdown rendering")
struct MarkdownRenderingTests {
    @Test("Parsing text yields a document distinct from parsing nothing")
    func parsesPlainText() async {
        let parser = MarkdownParserImpl()
        let empty = await parser.parse(text: "", config: .default)
        let filled = await parser.parse(text: "MANGO", config: .default)
        #expect(filled != empty, "parser produced nothing for plain text")
    }

    @Test("Rich markdown differs from plain text")
    func parsesRichMarkdown() async {
        let parser = MarkdownParserImpl()
        let plain = await parser.parse(text: "MANGO", config: .default)
        let rich = await parser.parse(
            text: "# Title\n\nSome **bold** text.\n\n- one\n- two",
            config: .default
        )
        #expect(rich != plain)
    }
}

import Markdown

@Suite("swift-markdown")
struct SwiftMarkdownTests {
    @Test("cmark parses a paragraph")
    func parsesParagraph() {
        let document = Document(parsing: "MANGO")
        #expect(document.childCount == 1, "cmark returned \(document.childCount) children")
    }

    @Test("cmark parses a heading and a list")
    func parsesStructure() {
        let document = Document(parsing: "# Title\n\n- one\n- two")
        #expect(document.childCount == 2)
    }
}
