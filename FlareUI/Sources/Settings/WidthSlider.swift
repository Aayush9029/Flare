import FlareKit
import SwiftUI

/// The panel's width on the same track as the model picker.
struct WidthSlider: View {
    @Bindable var preferences: Preferences

    @State private var preview: Int?

    private let widths = PanelSize.widths

    private var settled: Int {
        widths.firstIndex(of: CGFloat(preferences.panelWidth)) ?? nearest(CGFloat(preferences.panelWidth))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Width")
                Spacer()
                Text("\(Int(widths[preview ?? settled])) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.12), value: preview)
            }
            StopSlider(
                count: widths.count,
                index: settled,
                tint: [Color(red: 0.30, green: 0.62, blue: 1.0), Color(red: 0.15, green: 0.48, blue: 0.98)]
            ) { stop in
                preview = stop
            } onCommit: { stop in
                preferences.$panelWidth.withLock { $0 = Int(widths[stop]) }
            }
            .accessibilityElement()
            .accessibilityLabel("Panel width")
            .accessibilityValue("\(preferences.panelWidth) points")
        }
    }

    private func nearest(_ width: CGFloat) -> Int {
        widths.indices.min { abs(widths[$0] - width) < abs(widths[$1] - width) } ?? 1
    }
}
