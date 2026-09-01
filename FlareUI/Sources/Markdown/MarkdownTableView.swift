import SwiftUI

struct MarkdownTableView: View {
    let table: MarkdownTable

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(table.header.indices, id: \.self) { column in
                    cell(table.header[column], header: true)
                }
            }
            .background(.primary.opacity(0.05))
            ForEach(table.rows.indices, id: \.self) { row in
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    ForEach(table.rows[row].indices, id: \.self) { column in
                        cell(table.rows[row][column], header: false)
                    }
                }
            }
        }
        .clipShape(.rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
        }
        .font(.system(size: 12.5))
    }

    private func cell(_ cell: MarkdownTable.Cell, header: Bool) -> some View {
        Text(cell.text)
            .fontWeight(header ? .semibold : .regular)
            .multilineTextAlignment(alignment(cell.alignment))
            .frame(maxWidth: .infinity, alignment: frameAlignment(cell.alignment))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
    }

    private func alignment(_ alignment: NSTextAlignment) -> TextAlignment {
        switch alignment {
        case .center: .center
        case .right: .trailing
        default: .leading
        }
    }

    private func frameAlignment(_ alignment: NSTextAlignment) -> Alignment {
        switch alignment {
        case .center: .top
        case .right: .topTrailing
        default: .topLeading
        }
    }
}
