import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import FlareKit

@Suite("Sending", .serialized)
@MainActor
struct SendTests {
    private func makeModel(reply: String = "Hello there") -> FlareModel {
        withDependencies {
            try! $0.bootstrapDatabase()
            $0.chatClient = .echo(reply)
            $0.openAIAuth = .testValue
            $0.openAIAuth.isSignedIn = { true }
            $0.windowClient = .testValue
            $0.apiKeyStore = .ephemeral()
            $0.uuid = .incrementing
            $0.date = .init { Date() }
        } operation: {
            FlareModel()
        }
    }

    private func settle(_ model: FlareModel) async throws {
        let deadline = Date().addingTimeInterval(10)
        while model.isStreaming, Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!model.isStreaming, "stream never finished")
    }

    private func messages(_ model: FlareModel) throws -> [ChatMessage] {
        @Dependency(\.defaultDatabase) var database
        guard let threadID = model.selectedThreadID else { return [] }
        return try database.read { db in
            try ChatMessage
                .where { $0.threadID.eq(threadID) }
                .order { $0.createdAt.asc() }
                .fetchAll(db)
        }
    }

    @Test("A sent message is stored together with its reply")
    func storesBothMessages() async throws {
        let model = makeModel()
        try await withDependencies(from: model) {
            model.newThread()
            model.draft = "hi"
            model.send()
            try await settle(model)

            let stored = try messages(model)
            #expect(stored.count == 2)
            #expect(stored.first?.role == .user)
            #expect(stored.first?.content == "hi")
            #expect(stored.last?.role == .assistant)
            #expect(stored.last?.content.contains("Hello") == true)
            #expect(model.errorMessage == nil)
        }
    }

    /// Dismissing an untouched panel used to delete the selected thread while
    /// leaving its id selected, so the next send inserted against a missing row,
    /// rolled back, and silently dropped the message.
    @Test("Dismissing an unused panel still leaves sending working")
    func discardThenSend() async throws {
        let model = makeModel()
        try await withDependencies(from: model) {
            model.newThread()
            let discarded = try #require(model.selectedThreadID)

            model.discardEmptyThread(discarded)
            #expect(model.selectedThreadID == nil, "a deleted thread must not stay selected")

            model.open()
            #expect(model.selectedThreadID != nil)
            #expect(model.selectedThreadID != discarded)

            model.draft = "second attempt"
            model.send()
            try await settle(model)

            let stored = try messages(model)
            #expect(stored.count == 2, "the message must survive the discard")
            #expect(model.errorMessage == nil)
        }
    }

    @Test("A thread that holds messages is never discarded")
    func keepsUsedThread() async throws {
        let model = makeModel()
        try await withDependencies(from: model) {
            model.newThread()
            let threadID = try #require(model.selectedThreadID)
            model.draft = "keep me"
            model.send()
            try await settle(model)

            model.discardEmptyThread(threadID)
            #expect(model.selectedThreadID == threadID)
            let kept = try messages(model)
            #expect(kept.count == 2)
        }
    }

    @Test("The composer unlocks as soon as the answer lands")
    func streamStateClearsWithTheAnswer() async throws {
        let model = makeModel()
        try await withDependencies(from: model) {
            model.newThread()
            model.draft = "hi"
            model.send()
            try await settle(model)

            #expect(model.liveResponse == nil, "a live relay would render the answer twice")
            #expect(model.liveReasoning == nil)
        }
    }

    @Test("Sending without a credential reports instead of storing")
    func refusesWhenSignedOut() async throws {
        let model = withDependencies {
            try! $0.bootstrapDatabase()
            $0.chatClient = .echo("nope")
            $0.openAIAuth = .testValue
            $0.openAIAuth.isSignedIn = { false }
            $0.windowClient = .testValue
            $0.apiKeyStore = .ephemeral()
            $0.uuid = .incrementing
            $0.date = .init { Date() }
        } operation: {
            FlareModel()
        }

        try await withDependencies(from: model) {
            model.newThread()
            model.draft = "hi"
            model.send()

            #expect(model.errorMessage != nil)
            let stored = try messages(model)
            #expect(stored.isEmpty)
            #expect(model.draft == "hi", "the draft must survive a refused send")
        }
    }
}

/// The whole path a keystroke actually takes: model -> live client -> real API -> database.
@Suite(
    "Sending for real",
    .enabled(if: ProcessInfo.processInfo.environment["FLARE_LIVE_TESTS"] != nil),
    .serialized
)
@MainActor
struct LiveSendTests {
    @Test("A real send stores a real answer")
    func liveRoundTrip() async throws {
        let auth = withDependencies {
            $0.tokenStore = .liveValue
            $0.apiKeyStore = .liveValue
        } operation: {
            OpenAIAuthClient.liveValue
        }
        try #require(auth.isSignedIn(), "no credential on disk")

        let model = withDependencies {
            try! $0.bootstrapDatabase()
            $0.openAIAuth = auth
            $0.chatClient = withDependencies { $0.openAIAuth = auth } operation: { ChatClient.liveValue }
            $0.windowClient = .testValue
            $0.uuid = .incrementing
            $0.date = .init { Date() }
        } operation: {
            FlareModel()
        }

        try await withDependencies(from: model) {
            model.newThread()
            let threadID = try #require(model.selectedThreadID)
            model.draft = "Reply with exactly: PONG"
            model.send()

            let deadline = Date().addingTimeInterval(60)
            while model.isStreaming, Date() < deadline {
                try await Task.sleep(for: .milliseconds(50))
            }
            #expect(!model.isStreaming)
            #expect(model.errorMessage == nil, "send failed: \(model.errorMessage ?? "")")

            @Dependency(\.defaultDatabase) var database
            let stored = try await database.read { db in
                try ChatMessage
                    .where { $0.threadID.eq(threadID) }
                    .order { $0.createdAt.asc() }
                    .fetchAll(db)
            }
            #expect(stored.count == 2)
            #expect(stored.last?.content.contains("PONG") == true)
        }
    }
}

@Suite("Instructions")
struct InstructionsTests {
    @Test("Web search guidance is appended only when the tool is on")
    func appendsGuidance() {
        let on = FlareModel.instructions(prompt: "Be terse.", webSearch: true)
        let off = FlareModel.instructions(prompt: "Be terse.", webSearch: false)
        #expect(on.hasPrefix("Be terse."))
        #expect(on.contains("web_search"))
        #expect(off == "Be terse.")
    }
}
