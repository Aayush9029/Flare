import SwiftUI

struct MetricBars: View {
    let value: Int
    let maxValue: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxValue, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < value ? color : color.opacity(0.2))
                    .frame(width: 4, height: 8)
            }
        }
    }
}
