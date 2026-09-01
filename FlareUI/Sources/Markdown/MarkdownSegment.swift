import AppKit
import Foundation

/// A rendered slice of a message. Text runs go to one text view; tables, which
/// TextKit 2 cannot lay out, become a grid between them.
enum MarkdownSegment: Identifiable {
    case text(index: Int, NSAttributedString)
    case table(index: Int, MarkdownTable)

    var id: Int {
        switch self {
        case .text(let index, _), .table(let index, _): index
        }
    }
}

struct MarkdownTable: Equatable {
    struct Cell: Equatable {
        let text: AttributedString
        let alignment: NSTextAlignment
    }

    let header: [Cell]
    let rows: [[Cell]]
}

/// Crosses from the build task to the main actor. Attributed strings are immutable
/// once built, so sharing them is safe; the compiler cannot see that.
struct MarkdownBuild: @unchecked Sendable {
    let segments: [MarkdownSegment]
}
