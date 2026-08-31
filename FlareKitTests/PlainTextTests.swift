import Testing

@testable import FlareKit

@Suite("Plain text")
struct PlainTextTests {
    @Test("Emphasis markers are dropped, words kept")
    func stripsEmphasis() {
        #expect(MarkdownPlainText.from("Some **bold** and *italic* text.") == "Some bold and italic text.")
    }

    @Test("Inline code keeps its contents")
    func inlineCode() {
        #expect(MarkdownPlainText.from("Call `foo()` now.") == "Call foo() now.")
    }

    @Test("Links keep the label, not the URL")
    func links() {
        #expect(MarkdownPlainText.from("See [the docs](https://swift.org).") == "See the docs.")
    }

    @Test("Headings lose their hashes")
    func headings() {
        #expect(MarkdownPlainText.from("# Title\n\nBody.") == "Title\n\nBody.")
    }

    @Test("Bullets become readable markers")
    func lists() {
        #expect(MarkdownPlainText.from("- one\n- two") == "• one\n• two")
    }

    @Test("Fenced code keeps the code and drops the fence")
    func codeBlocks() {
        #expect(MarkdownPlainText.from("```swift\nlet x = 1\n```") == "let x = 1")
    }

    @Test("Copying as Markdown is the untouched source")
    func markdownIsVerbatim() {
        let source = "# Title\n\n- **a**\n- `b`"
        #expect(MarkdownPlainText.from(source) != source)
    }
}

@Suite("Tools")
struct ToolSelectionTests {
    @Test("Toggles decide which tools go on the request")
    func toolSelection() {
        #expect(FlareModel.tools(webSearch: false, images: false).isEmpty)
        #expect(FlareModel.tools(webSearch: true, images: false).map(\.type) == ["web_search"])
        #expect(FlareModel.tools(webSearch: false, images: true).map(\.type) == ["image_generation"])
        #expect(
            FlareModel.tools(webSearch: true, images: true).map(\.type)
                == ["web_search", "image_generation"]
        )
    }

    @Test("Image generation carries a size and quality")
    func imageToolShape() {
        let tool = ResponsesAPI.Tool.imageGeneration
        #expect(tool.size == "1024x1024")
        #expect(tool.quality == "low")
    }
}
