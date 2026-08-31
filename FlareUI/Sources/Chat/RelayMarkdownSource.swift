import FlareKit
import SwiftStreamingMarkdown

struct RelayMarkdownSource: StreamedMarkdownSource {
    let relay: MarkdownRelay

    var text: AsyncStream<String> { relay.stream() }
}
