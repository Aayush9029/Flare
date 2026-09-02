import Foundation
import os

protocol StreamDecoder: Sendable {
    mutating func decode(_ payload: Data) -> [StreamEvent]
    /// Whatever the decoder held back, once the stream ends.
    mutating func finish() -> [StreamEvent]
}

extension StreamDecoder {
    mutating func finish() -> [StreamEvent] { [] }
}

enum StreamingHTTP {
    static let logger = Logger(subsystem: "ca.optimalapps.flare", category: "chat")

    static func open(_ request: URLRequest, provider: String) async throws -> URLSession.AsyncBytes {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ChatError.server(provider, -1, "no response")
        }
        switch http.statusCode {
        case 200..<300:
            return bytes
        case 401, 403:
            throw ChatError.unauthorized(provider)
        case 429:
            throw ChatError.rateLimited(provider)
        default:
            var body = ""
            for try await line in bytes.lines where body.count < 2000 { body += line }
            logger.error(
                """
                \(http.statusCode, privacy: .public) from \(request.url?.host() ?? "?", privacy: .public)
                request: \(String(decoding: request.httpBody ?? Data(), as: UTF8.self), privacy: .public)
                response: \(body, privacy: .public)
                """
            )
            throw ChatError.server(provider, http.statusCode, message(in: body) ?? String(body.prefix(200)))
        }
    }

    /// The message inside a JSON error body, in either of the shapes servers use.
    static func message(in body: String) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else { return nil }
        if let text = object["error"] as? String { return text }
        return (object["error"] as? [String: Any])?["message"] as? String ?? object["message"] as? String
    }

    /// Decodes SSE payloads as they arrive. A stream that ends without saying it
    /// completed still completes: only a cancellation counts as stopped.
    static func events<D: StreamDecoder>(from bytes: URLSession.AsyncBytes, decoder: D) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var decoder = decoder
                var parser = SSEParser()
                var chunk = Data()
                var completed = false

                func emit(_ events: [StreamEvent]) {
                    for event in events where !completed {
                        continuation.yield(event)
                        if case .completed = event { completed = true }
                    }
                }

                do {
                    for try await byte in bytes {
                        chunk.append(byte)
                        guard byte == 0x0A else { continue }
                        let payloads = parser.consume(chunk)
                        chunk.removeAll(keepingCapacity: true)
                        for payload in payloads {
                            emit(decoder.decode(payload))
                            if completed { break }
                        }
                        if completed { break }
                    }
                    if !completed {
                        emit(decoder.finish())
                        emit([.completed])
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
