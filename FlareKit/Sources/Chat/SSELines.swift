import Foundation

/// Reassembles `data:` payloads from a byte stream of server-sent events.
struct SSEParser {
    private var buffer = Data()

    mutating func consume(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var payloads: [Data] = []
        while let range = buffer.range(of: Data("\n\n".utf8)) ?? buffer.range(of: Data("\r\n\r\n".utf8)) {
            let block = buffer[buffer.startIndex..<range.lowerBound]
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if let payload = Self.dataField(in: block) { payloads.append(payload) }
        }
        return payloads
    }

    private static func dataField(in block: Data) -> Data? {
        guard let text = String(data: block, encoding: .utf8) else { return nil }
        let values = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> Substring? in
                guard line.hasPrefix("data:") else { return nil }
                var value = line.dropFirst(5)
                if value.hasPrefix(" ") { value = value.dropFirst() }
                return value
            }
        guard !values.isEmpty else { return nil }
        let joined = values.joined(separator: "\n")
        guard joined != "[DONE]" else { return nil }
        return Data(joined.utf8)
    }
}
