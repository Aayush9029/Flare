import Foundation
import Testing

@testable import FlareKit

@Suite("SSE parsing")
struct SSEParserTests {
    @Test("Extracts one payload per event block")
    func singleBlock() {
        var parser = SSEParser()
        let payloads = parser.consume(Data("data: {\"a\":1}\n\n".utf8))
        #expect(payloads.count == 1)
        #expect(String(data: payloads[0], encoding: .utf8) == "{\"a\":1}")
    }

    @Test("Reassembles a payload split across chunks")
    func splitAcrossChunks() {
        var parser = SSEParser()
        #expect(parser.consume(Data("data: {\"a\"".utf8)).isEmpty)
        #expect(parser.consume(Data(":1}".utf8)).isEmpty)
        let payloads = parser.consume(Data("\n\n".utf8))
        #expect(String(data: payloads[0], encoding: .utf8) == "{\"a\":1}")
    }

    @Test("Joins multi-line data fields and drops event/id lines")
    func multiLine() {
        var parser = SSEParser()
        let payloads = parser.consume(Data("event: delta\nid: 7\ndata: one\ndata: two\n\n".utf8))
        #expect(String(data: payloads[0], encoding: .utf8) == "one\ntwo")
    }

    @Test("Ignores the terminal [DONE] sentinel")
    func doneSentinel() {
        var parser = SSEParser()
        #expect(parser.consume(Data("data: [DONE]\n\n".utf8)).isEmpty)
    }

    @Test("Handles CRLF framing")
    func crlf() {
        var parser = SSEParser()
        let payloads = parser.consume(Data("data: hi\r\n\r\n".utf8))
        #expect(String(data: payloads[0], encoding: .utf8) == "hi")
    }
}

@Suite("Stream event decoding")
struct StreamEventTests {
    private func decode(_ json: String) -> StreamEvent? {
        StreamEvent.decode(Data(json.utf8))
    }

    @Test("Decodes an output text delta")
    func outputDelta() {
        #expect(decode(#"{"type":"response.output_text.delta","delta":"Hel"}"#) == .outputTextDelta("Hel"))
    }

    @Test("Decodes a reasoning summary delta")
    func reasoningDelta() {
        #expect(
            decode(#"{"type":"response.reasoning_summary_text.delta","delta":"Think"}"#)
                == .reasoningSummaryDelta("Think")
        )
    }

    @Test("Separates reasoning summary parts with a paragraph break")
    func reasoningPartBoundary() {
        #expect(decode(#"{"type":"response.reasoning_summary_part.added","summary_index":0}"#) == nil)
        #expect(
            decode(#"{"type":"response.reasoning_summary_part.added","summary_index":1}"#)
                == .reasoningSummaryDelta("\n\n")
        )
    }

    @Test("Decodes completion")
    func completed() {
        #expect(decode(#"{"type":"response.completed"}"#) == .completed)
    }

    @Test("Surfaces the server's failure message")
    func failure() {
        #expect(
            decode(#"{"type":"response.failed","response":{"error":{"message":"quota"}}}"#)
                == .failed("quota")
        )
    }

    @Test("Ignores event types Flare does not render")
    func unknown() {
        #expect(decode(#"{"type":"response.in_progress"}"#) == nil)
    }
}
