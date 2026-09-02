import Foundation
import Testing

@testable import FlareKit

@Suite("Chat Completions stream")
struct ChatCompletionsDecodingTests {
    private func events(_ payloads: [String]) -> [StreamEvent] {
        var decoder = ChatCompletionsAPI.EventDecoder()
        var events = payloads.flatMap { decoder.decode(Data($0.utf8)) }
        events += decoder.finish()
        return events
    }

    @Test("Content and OpenRouter reasoning deltas map to their events")
    func reasoningField() {
        let events = events([
            #"{"choices":[{"delta":{"role":"assistant","reasoning":"Let me see"}}]}"#,
            #"{"choices":[{"delta":{"content":"Hi"}}]}"#,
            #"{"choices":[{"delta":{"content":" there"},"finish_reason":"stop"}]}"#,
        ])
        #expect(events == [.reasoningSummaryDelta("Let me see"), .outputTextDelta("Hi"), .outputTextDelta(" there")])
    }

    @Test("reasoning_content, the vLLM and llama.cpp field, counts too")
    func reasoningContentField() {
        let events = events([#"{"choices":[{"delta":{"reasoning_content":"hmm"}}]}"#])
        #expect(events == [.reasoningSummaryDelta("hmm")])
    }

    @Test("Think tags split across chunks still separate thoughts from the answer")
    func thinkTags() {
        let events = events([
            #"{"choices":[{"delta":{"content":"<thi"}}]}"#,
            #"{"choices":[{"delta":{"content":"nk>plan"}}]}"#,
            #"{"choices":[{"delta":{"content":" it</th"}}]}"#,
            #"{"choices":[{"delta":{"content":"ink>\n\nAnswer"}}]}"#,
            #"{"choices":[{"delta":{"content":" here <b>"}}]}"#,
        ])
        #expect(events == [
            .reasoningSummaryDelta("plan"),
            .reasoningSummaryDelta(" it"),
            .outputTextDelta("Answer"),
            .outputTextDelta(" here <b>"),
        ])
    }

    @Test("A think tag inside the answer is text, not a switch")
    func literalThinkTag() {
        let events = events([
            #"{"choices":[{"delta":{"content":"Wrap it in <thi"}}]}"#,
            #"{"choices":[{"delta":{"content":"nk> tags."}}]}"#,
        ])
        #expect(events == [.outputTextDelta("Wrap it in "), .outputTextDelta("<think> tags.")])
    }

    @Test("An error object becomes a failure")
    func errorObject() {
        let events = events([#"{"error":{"message":"Model not found","code":404}}"#])
        #expect(events == [.failed("Model not found")])
    }
}

@Suite("Anthropic stream")
struct AnthropicDecodingTests {
    private func events(_ payloads: [String]) -> [StreamEvent] {
        var decoder = AnthropicAPI.EventDecoder()
        return payloads.flatMap { decoder.decode(Data($0.utf8)) }
    }

    @Test("Thinking, text, citations and the stop map to their events")
    func fullTurn() {
        let events = events([
            #"{"type":"message_start","message":{"id":"m"}}"#,
            #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#,
            #"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"weigh it"}}"#,
            #"{"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"x"}}"#,
            #"{"type":"content_block_start","index":1,"content_block":{"type":"server_tool_use","name":"web_search"}}"#,
            #"{"type":"content_block_start","index":2,"content_block":{"type":"web_search_tool_result"}}"#,
            #"{"type":"content_block_start","index":3,"content_block":{"type":"text","text":""}}"#,
            #"{"type":"content_block_delta","index":3,"delta":{"type":"text_delta","text":"Swift 6.3"}}"#,
            #"{"type":"content_block_delta","index":3,"delta":{"type":"citations_delta","citation":{"type":"web_search_result_location","url":"https://swift.org","title":"Swift"}}}"#,
            #"{"type":"message_delta","delta":{"stop_reason":"end_turn"}}"#,
            #"{"type":"message_stop"}"#,
        ])
        #expect(events == [
            .reasoningSummaryDelta("weigh it"),
            .webSearchStarted,
            .webSearchFinished,
            .outputTextDelta("Swift 6.3"),
            .citation(Citation(title: "Swift", url: "https://swift.org")),
            .completed,
        ])
    }

    @Test("A second thinking block starts a new paragraph")
    func thinkingBlocks() {
        let events = events([
            #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking"}}"#,
            #"{"type":"content_block_start","index":1,"content_block":{"type":"thinking"}}"#,
        ])
        #expect(events == [.reasoningSummaryDelta("\n\n")])
    }

    @Test("An error event becomes a failure")
    func errorEvent() {
        let events = events([#"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#])
        #expect(events == [.failed("Overloaded")])
    }
}

@Suite("Provider requests")
struct ProviderRequestTests {
    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        return encoder
    }

    @Test("Anthropic turns carry images as base64 sources and efforts as budgets")
    func anthropicRequest() throws {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let request = AnthropicAPI.Request(
            model: "claude-sonnet-5",
            effort: "medium",
            instructions: "Be terse.",
            turns: [
                ChatTurn(role: "user", text: "what is this", images: [png]),
                ChatTurn(role: "assistant", text: "A logo.\n"),
                ChatTurn(role: "user", text: "sure?"),
            ],
            webSearch: true
        )
        let json = String(decoding: try encoder.encode(request), as: UTF8.self)
        #expect(json.contains(#""thinking":{"budget_tokens":8192,"type":"enabled"}"#))
        #expect(json.contains(#""max_tokens":24576"#))
        #expect(json.contains(#""media_type":"image/png""#))
        #expect(json.contains(#""text":"A logo.""#), "trailing whitespace on an assistant turn is trimmed")
        #expect(json.contains(#""type":"web_search_20250305""#))
        #expect(json.contains(#""system":"Be terse.""#))
    }

    @Test("Without an effort Anthropic gets no thinking block")
    func anthropicNoThinking() throws {
        let request = AnthropicAPI.Request(model: "m", effort: nil, instructions: "", turns: [ChatTurn(role: "user", text: "hi")], webSearch: false)
        let json = String(decoding: try encoder.encode(request), as: UTF8.self)
        #expect(!json.contains("thinking"))
        #expect(json.contains(#""tools":[]"#))
    }

    @Test("Chat Completions sends plain strings unless a turn has images")
    func chatCompletionsRequest() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let request = ChatCompletionsAPI.Request(
            model: "qwen3",
            effort: "high",
            instructions: "Be terse.",
            turns: [
                ChatTurn(role: "user", text: "hello"),
                ChatTurn(role: "assistant", text: "hi"),
                ChatTurn(role: "user", text: "look", images: [jpeg]),
            ],
            isOpenRouter: false
        )
        let json = String(decoding: try encoder.encode(request), as: UTF8.self)
        #expect(json.contains(#"{"content":"Be terse.","role":"system"}"#))
        #expect(json.contains(#"{"content":"hello","role":"user"}"#))
        #expect(json.contains(#""image_url":{"url":"data:image/jpeg;base64,"#))
        #expect(json.contains(#""reasoning_effort":"high""#))
        #expect(!json.contains(#""reasoning":"#))
    }

    @Test("OpenRouter takes the effort as a reasoning object; Off sends neither")
    func openRouterReasoning() throws {
        let routed = ChatCompletionsAPI.Request(model: "m", effort: "low", instructions: "", turns: [], isOpenRouter: true)
        let json = String(decoding: try encoder.encode(routed), as: UTF8.self)
        #expect(json.contains(#""reasoning":{"effort":"low"}"#))
        #expect(!json.contains("reasoning_effort"))

        let off = ChatCompletionsAPI.Request(model: "m", effort: "none", instructions: "", turns: [], isOpenRouter: true)
        let offJSON = String(decoding: try encoder.encode(off), as: UTF8.self)
        #expect(!offJSON.contains("reasoning"))
    }

    @Test("Model listings are read in every dialect")
    func modelListing() {
        let openRouter = #"{"data":[{"id":"openai/gpt-5.6-terra","name":"OpenAI: GPT-5.6 Terra","context_length":400000,"supported_parameters":["reasoning","tools"],"architecture":{"input_modalities":["text","image"],"output_modalities":["text"]}},{"id":"meta/llama","name":"Llama","supported_parameters":["tools"]},{"id":"openai/gpt-image","name":"Image","architecture":{"input_modalities":["text"],"output_modalities":["image"]}}]}"#
        let routed = ModelListing.parse(Data(openRouter.utf8))
        #expect(routed.map(\.id) == ["openai/gpt-5.6-terra", "meta/llama"], "an image-out model is not a chat model")
        #expect(routed[0].efforts == ["low", "medium", "high"])
        #expect(routed[0].context == 400_000)
        #expect(routed[0].contextLabel == "400K")
        #expect(routed[0].groupTitle == "Openai")
        #expect(routed[1].efforts == [])
        #expect(routed[0].shortName == "OpenAI: 5.6 Terra")
        #expect(!ModelListing.isChatModel(ModelInfo(id: "whisper-large-v3")))
        #expect(ModelListing.isChatModel(ModelInfo(id: "models/gemini-2.5-flash")))
        #expect(ModelInfo(id: "models/gemini-2.5-flash").groupKey == "gemini")
        #expect(ModelInfo(id: "models/gemini-2.5-flash").shortName == "gemini-2.5-flash")
        #expect(ModelMetadata.metrics(for: "openai/gpt-oss-120b")?.speed == 4)

        let ollama = #"{"object":"list","data":[{"id":"qwen3:32b","object":"model","owned_by":"library"}]}"#
        let local = ModelListing.parse(Data(ollama.utf8))
        #expect(local == [ModelInfo(id: "qwen3:32b")])
        #expect(local[0].efforts == nil)

        let anthropic = #"{"data":[{"id":"claude-sonnet-5-20260815","display_name":"Claude Sonnet 5","type":"model"}],"has_more":false}"#
        #expect(ModelListing.parse(Data(anthropic.utf8))[0].name == "Claude Sonnet 5")
    }

    @Test("Vendors without a listing get their known efforts")
    func hints() {
        #expect(ProviderHints.efforts(host: "api.groq.com", modelID: "openai/gpt-oss-120b") == ["low", "medium", "high"])
        #expect(ProviderHints.efforts(host: "api.groq.com", modelID: "llama-3.3-70b-versatile") == [])
        #expect(ProviderHints.efforts(host: "generativelanguage.googleapis.com", modelID: "models/gemini-2.5-flash") == ["low", "medium", "high"])
        #expect(ProviderHints.efforts(host: "api.mistral.ai", modelID: "mistral-small-latest") == [])
        #expect(ProviderHints.efforts(host: "desk.local", modelID: "qwen3") == nil)
        let groq = #"{"data":[{"id":"openai/gpt-oss-120b","name":"GPT-OSS 120B"}]}"#
        #expect(ModelListing.parse(Data(groq.utf8), host: "api.groq.com")[0].efforts == ["low", "medium", "high"])
    }

    @Test("Hosts map to their brand marks")
    func icons() {
        #expect(ProviderIcon.name(for: URL(string: "https://openrouter.ai/api/v1")!) == "openrouter")
        #expect(ProviderIcon.name(for: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!) == "gemini")
        #expect(ProviderIcon.name(for: URL(string: "http://localhost:11434/v1")!) == "ollama")
        #expect(ProviderIcon.name(for: URL(string: "https://models.inference.ai.azure.com")!) == "github")
        #expect(ProviderIcon.name(for: URL(string: "http://desk.local:8080/v1")!) == nil)
        #expect(ProviderIcon.name(for: .anthropic) == "anthropic")
        #expect(ProviderIcon.name(for: .openRouter) == "openrouter")
    }

    @Test("Base URLs are normalised")
    func normalise() {
        #expect(CustomProvider.normalize(" localhost:8080/v1/ ")?.absoluteString == "http://localhost:8080/v1")
        #expect(CustomProvider.normalize("https://openrouter.ai/api/v1")?.absoluteString == "https://openrouter.ai/api/v1")
        #expect(CustomProvider.normalize("") == nil)
    }
}
