import FlareKit
import SwiftUI

/// The reasoning stops a listed model takes, Off first, on the same track as the model slider.
struct EffortSlider: View {
    let efforts: [String]
    let effort: String?
    var onPreview: (String?) -> Void = { _ in }
    var onCommit: (String) -> Void

    private var settled: Int {
        efforts.firstIndex(of: effort ?? Effort.none) ?? 0
    }

    var body: some View {
        StopSlider(count: efforts.count, index: settled) { stop in
            onPreview(stop.map { efforts[$0] })
        } onCommit: { stop in
            onCommit(efforts[stop])
        }
        .accessibilityElement()
        .accessibilityLabel("Reasoning")
        .accessibilityValue(Effort.title(effort))
    }
}
