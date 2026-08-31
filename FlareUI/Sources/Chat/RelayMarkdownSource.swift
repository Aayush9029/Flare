import FlareKit
import SwiftStreamingMarkdown

/// Bridges `MarkdownRelay` to the shape `StreamedMarkdownView` expects.
struct RelayMarkdownSource: StreamedMarkdownSource {
    let relay: MarkdownRelay

    var text: AsyncStream<String> { relay.stream() }
}
