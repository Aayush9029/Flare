import Foundation
import Testing
@testable import FlareKit

@Suite("Request encoding")
struct RequestEncodingTests {
    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return encoder
    }

    @Test("A user turn with an image carries an input_image part")
    func imagePart() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let item = ResponsesAPI.Item(role: "user", text: "what is this", images: [png])
        let json = String(decoding: try encoder.encode(item), as: UTF8.self)
        #expect(json.contains("\"type\":\"input_text\""))
        #expect(json.contains("\"type\":\"input_image\""))
        #expect(json.contains("\"image_url\":\"data:image/png;base64,\(png.base64EncodedString())\""))
    }

    @Test("An image alone still forms a message")
    func imageOnly() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let item = ResponsesAPI.Item(role: "user", text: "", images: [jpeg])
        let json = String(decoding: try encoder.encode(item), as: UTF8.self)
        #expect(!json.contains("input_text"))
        #expect(json.contains("data:image/jpeg;base64,"))
    }

    @Test("Assistant turns never carry images")
    func assistantIgnoresImages() throws {
        let item = ResponsesAPI.Item(role: "assistant", text: "sure", images: [Data([0x89, 0x50, 0x4E, 0x47])])
        let json = String(decoding: try encoder.encode(item), as: UTF8.self)
        #expect(!json.contains("input_image"))
    }
}
