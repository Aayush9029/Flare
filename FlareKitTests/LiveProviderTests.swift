import Dependencies
import Foundation
import Testing

@testable import FlareKit

/// Every OpenAI-compatible vendor there is a key for in the environment: the listing,
/// a plain answer, and thoughts where the vendor streams them. `TEST_RUNNER_` carries
/// the keys through xcodebuild.
@Suite(
    "Live providers",
    .enabled(if: ProcessInfo.processInfo.environment["FLARE_LIVE_TESTS"] != nil),
    .serialized
)
struct LiveProviderTests {
    struct Vendor: CustomTestStringConvertible {
        let name: String
        /// A built-in kind, or nil for an endpoint added by hand.
        var kind: ProviderKind? = nil
        let baseURL: String
        let keyVariable: String
        /// Preferred chat models, first listed wins.
        let chat: [String]
        /// Models expected to stream thoughts with an effort set.
        let reasoning: [String]

        var testDescription: String { name }
    }

    static let vendors = [
        Vendor(
            name: "OpenRouter",
            kind: .openRouter,
            baseURL: "https://openrouter.ai/api/v1",
            keyVariable: "OPENROUTER_API_KEY",
            chat: ["openai/gpt-6-luna", "openai/gpt-4.1-nano", "google/gemini-3.5-flash-lite"],
            reasoning: ["openai/gpt-oss-120b", "openai/gpt-oss-20b", "deepseek/deepseek-r1-0528"]
        ),
        Vendor(
            name: "Groq",
            kind: .groq,
            baseURL: "https://api.groq.com/openai/v1",
            keyVariable: "GROQ_API_KEY",
            chat: ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "qwen/qwen3.6-27b", "openai/gpt-oss-20b"],
            reasoning: ["openai/gpt-oss-120b", "openai/gpt-oss-20b"]
        ),
        Vendor(
            name: "Mistral",
            baseURL: "https://api.mistral.ai/v1",
            keyVariable: "MISTRAL_API_KEY",
            chat: ["mistral-small-latest", "ministral-8b-latest", "open-mistral-nemo"],
            reasoning: []
        ),
        Vendor(
            name: "xAI",
            baseURL: "https://api.x.ai/v1",
            keyVariable: "XAI_API_KEY",
            chat: ["grok-4.20-0309-non-reasoning", "grok-3-mini", "grok-4.3"],
            reasoning: []
        ),
        Vendor(
            name: "Gemini",
            kind: .gemini,
            baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
            keyVariable: "GEMINI_API_KEY",
            chat: ["models/gemini-2.5-flash-lite", "models/gemini-2.5-flash", "models/gemini-3-flash"],
            reasoning: []
        ),
    ]

    private func key(for vendor: Vendor) -> String? {
        let value = ProcessInfo.processInfo.environment[vendor.keyVariable] ?? ""
        return value.isEmpty ? nil : value
    }

    private func client(for vendor: Vendor, key: String) -> (ChatClient, ChatEndpoint) {
        let baseURL = URL(string: vendor.baseURL)!
        let file: ProviderFile
        let providerID: String
        if let kind = vendor.kind {
            providerID = kind.rawValue
            file = ProviderFile(keys: [providerID: key])
        } else {
            let custom = CustomProvider(id: UUID(), name: vendor.name, baseURL: baseURL)
            providerID = custom.id.uuidString
            file = ProviderFile(keys: [providerID: key], custom: [custom])
        }
        let chat = withDependencies {
            $0.openAIAuth = .testValue
            $0.apiKeyStore = .ephemeral()
            $0.providerStore = .ephemeral(file)
        } operation: {
            ChatClient.liveValue
        }
        return (chat, .compatible(baseURL: baseURL, providerID: providerID))
    }

    private func run(_ chat: ChatClient, _ request: ChatRequest) async throws -> (text: String, reasoning: String) {
        var text = ""
        var reasoning = ""
        for try await event in try await chat.stream(request) {
            switch event {
            case .outputTextDelta(let delta): text += delta
            case .reasoningSummaryDelta(let delta): reasoning += delta
            case .failed(let message): Issue.record("stream failed: \(message)")
            default: break
            }
        }
        return (text, reasoning)
    }

    @Test("Lists models, answers, and streams thoughts where offered", arguments: vendors)
    func vendor(_ vendor: Vendor) async throws {
        guard let key = key(for: vendor) else {
            print("skipping \(vendor.name): \(vendor.keyVariable) is not set")
            return
        }
        let (chat, endpoint) = client(for: vendor, key: key)
        let models = try await ProviderClient.liveValue.listModels(endpoint, key)
        #expect(!models.isEmpty, "\(vendor.name) listed nothing")
        let ids = Set(models.map(\.id))

        let model = try #require(vendor.chat.first { ids.contains($0) }, "\(vendor.name) lists none of \(vendor.chat)")
        let plain = try await run(
            chat,
            ChatRequest(
                endpoint: endpoint,
                model: model,
                effort: nil,
                instructions: "Be terse.",
                turns: [
                    ChatTurn(role: "user", text: "Say A"),
                    ChatTurn(role: "assistant", text: "A"),
                    ChatTurn(role: "user", text: "Reply with exactly: PONG"),
                ]
            )
        )
        #expect(plain.text.contains("PONG"), "\(vendor.name)/\(model) answered: \(plain.text)")

        guard let thinker = vendor.reasoning.first(where: { ids.contains($0) }) else { return }
        let listed = try #require(models.first { $0.id == thinker })
        #expect(listed.efforts?.isEmpty == false, "\(vendor.name) should mark \(thinker) as reasoning")
        let thought = try await run(
            chat,
            ChatRequest(
                endpoint: endpoint,
                model: thinker,
                effort: Effort.low,
                instructions: "Be terse.",
                turns: [ChatTurn(role: "user", text: "Reply with exactly: PONG")]
            )
        )
        #expect(thought.text.contains("PONG"), "\(vendor.name)/\(thinker) answered: \(thought.text)")
        #expect(!thought.reasoning.isEmpty, "\(vendor.name)/\(thinker) streamed no thoughts")
    }

    @Test("A vision turn reaches an OpenAI-compatible vendor as image parts")
    func imageTurn() async throws {
        let vendor = Self.vendors[0]
        guard let key = key(for: vendor) else { return }
        let (chat, endpoint) = client(for: vendor, key: key)
        // A 64x64 solid red PNG.
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAeUlEQVR4nO3PQQkAMAzAwIqof2UTMxF7HINABFzm7H7dcEEDWtCAFjSgBQ1oQQNa0IAWNKAFDWhBA1rQgBY0oAUNaEEDWtCAFjSgBQ1oQQNa0IAWNKAFDWhBA1rQgBY0oAUNaEEDWtCAFjSgBQ1oQQNa0IAWNKAFj12qxUDxeFqrFAAAAABJRU5ErkJggg==")!
        let answer = try await run(
            chat,
            ChatRequest(
                endpoint: endpoint,
                model: "openai/gpt-6-luna",
                effort: nil,
                instructions: "Be terse.",
                turns: [ChatTurn(role: "user", text: "What colour is this image? One word.", images: [png])]
            )
        )
        #expect(answer.text.lowercased().contains("red"), "answered: \(answer.text)")
    }
}
