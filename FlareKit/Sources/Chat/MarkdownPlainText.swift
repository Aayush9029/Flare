import Foundation
import Markdown

/// Strips Markdown to the text a reader would actually see, for "Copy".
public enum MarkdownPlainText {
    public static func from(_ markdown: String) -> String {
        var walker = PlainTextWalker()
        walker.visit(Document(parsing: markdown))
        return walker.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PlainTextWalker: MarkupWalker {
    var output = ""
    private var listDepth = 0

    mutating func visitText(_ text: Text) {
        output += text.string
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        output += inlineCode.code
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        output += " "
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        output += "\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        output += codeBlock.code.trimmingCharacters(in: .newlines) + "\n\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        output += "\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        descendInto(paragraph)
        output += listDepth > 0 ? "\n" : "\n\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        descendInto(heading)
        output += "\n\n"
    }

    mutating func visitListItem(_ listItem: ListItem) {
        output += String(repeating: "  ", count: max(listDepth - 1, 0)) + "• "
        descendInto(listItem)
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        listDepth += 1
        descendInto(unorderedList)
        listDepth -= 1
        if listDepth == 0 { output += "\n" }
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        listDepth += 1
        descendInto(orderedList)
        listDepth -= 1
        if listDepth == 0 { output += "\n" }
    }

    mutating func visitTable(_ table: Table) {
        descendInto(table)
        output += "\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) {
        descendInto(tableRow)
        output += "\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) {
        descendInto(tableCell)
        output += "\t"
    }
}
