import FlareKit
import Observation
import SwiftUI

/// Builds a relay's latest snapshot off the main thread. Snapshots that arrive
/// while a build runs collapse into one more build, so the view never queues up
/// stale renders behind the stream.
@MainActor
@Observable
final class MarkdownDocumentModel {
    private(set) var segments: [MarkdownSegment] = []

    let relay: MarkdownRelay
    private let theme: MarkdownTheme
    @ObservationIgnored private var latestText = ""
    @ObservationIgnored private var isDark = false
    @ObservationIgnored private var buildTask: Task<Void, Never>?
    @ObservationIgnored private var needsBuild = false
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var lastBuild: ContinuousClock.Instant?

    /// A stream sends snapshots faster than the eye reads them; each build that lands
    /// costs a layout and a redraw on the main thread.
    private static let buildInterval = Duration.milliseconds(33)

    init(relay: MarkdownRelay, theme: MarkdownTheme) {
        self.relay = relay
        self.theme = theme
    }

    /// Idempotent: two views may share one model, and only one subscription is wanted.
    func run(isDark: Bool) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        self.isDark = isDark
        for await snapshot in relay.stream() {
            latestText = snapshot
            scheduleBuild()
        }
    }

    func setAppearance(isDark: Bool) {
        guard self.isDark != isDark else { return }
        self.isDark = isDark
        scheduleBuild()
    }

    func refresh() {
        scheduleBuild()
    }

    private func scheduleBuild() {
        guard buildTask == nil else {
            needsBuild = true
            return
        }
        buildTask = Task { [weak self] in
            if let lastBuild = self?.lastBuild {
                let wait = Self.buildInterval - (ContinuousClock.now - lastBuild)
                if wait > .zero { try? await Task.sleep(for: wait) }
            }
            // The build reads the newest snapshot, so whatever arrived while waiting is in it.
            self?.needsBuild = false
            await self?.build()
            guard let self else { return }
            self.buildTask = nil
            if self.needsBuild {
                self.needsBuild = false
                self.scheduleBuild()
            }
        }
    }

    private func build() async {
        let text = latestText
        let builder = MarkdownDocumentBuilder(theme: theme, isDark: isDark)
        let output = await Task.detached(priority: .userInitiated) {
            let output = builder.build(text)
            return (MarkdownBuild(segments: output.segments), output.pendingHighlights)
        }.value
        segments = output.0.segments
        lastBuild = .now
        for key in output.1 {
            Task {
                await CodeHighlighter.shared.request(key) { [weak self] in
                    Task { @MainActor in self?.refresh() }
                }
            }
        }
    }
}
