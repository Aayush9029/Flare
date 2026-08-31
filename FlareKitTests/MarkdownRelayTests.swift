import Testing

@testable import FlareKit

@Suite("Markdown relay")
struct MarkdownRelayTests {
    @Test("Emits growing snapshots, not deltas")
    func snapshots() async {
        let relay = MarkdownRelay()
        let stream = relay.stream()

        relay.append("Hel")
        relay.append("lo")
        relay.finish()

        var received: [String] = []
        for await snapshot in stream { received.append(snapshot) }

        #expect(received == ["", "Hel", "Hello"])
    }

    @Test("A late reader replays the text so far")
    func lateReader() async {
        let relay = MarkdownRelay()
        relay.append("already here")

        let stream = relay.stream()
        relay.finish()

        var received: [String] = []
        for await snapshot in stream { received.append(snapshot) }

        #expect(received == ["already here"])
    }

    @Test("A reader attached after finishing gets the final text and ends")
    func readerAfterFinish() async {
        let relay = MarkdownRelay()
        relay.append("done")
        relay.finish()

        var received: [String] = []
        for await snapshot in relay.stream() { received.append(snapshot) }

        #expect(received == ["done"])
    }

    @Test("Two readers see the same snapshots")
    func multipleReaders() async {
        let relay = MarkdownRelay()
        let first = relay.stream()
        let second = relay.stream()

        relay.append("x")
        relay.finish()

        async let a = collect(first)
        async let b = collect(second)
        let (left, right) = await (a, b)

        #expect(left == ["", "x"])
        #expect(right == left)
    }

    private func collect(_ stream: AsyncStream<String>) async -> [String] {
        var values: [String] = []
        for await value in stream { values.append(value) }
        return values
    }
}
