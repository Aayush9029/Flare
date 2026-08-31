import Dependencies
import DependenciesTestSupport
import Foundation
import IdentifiedCollections
import SQLiteData
import Testing

@testable import FlareKit

@Suite("FTS query building")
struct FTSQueryTests {
    @Test("Every token becomes a quoted prefix term")
    func prefixTerms() {
        #expect(MessageSearch.ftsQuery("swift concurrency") == "\"swift\"* \"concurrency\"*")
    }

    @Test("Punctuation is stripped rather than treated as FTS syntax")
    func stripsOperators() {
        #expect(MessageSearch.ftsQuery("NOT (a OR b)*") == "\"NOT\"* \"a\"* \"OR\"* \"b\"*")
        #expect(MessageSearch.ftsQuery("foo\"bar") == "\"foo\"* \"bar\"*")
    }

    @Test("A query with no word characters yields no FTS query")
    func emptyQuery() {
        #expect(MessageSearch.ftsQuery("   ") == nil)
        #expect(MessageSearch.ftsQuery("!!!") == nil)
    }
}

@Suite("Message search")
struct MessageSearchTests {
    @Test("Finds the thread holding a matching message")
    func findsMatch() async throws {
        try await withDependencies {
            try $0.bootstrapDatabase()
        } operation: {
            @Dependency(\.defaultDatabase) var database

            let swiftThread = ChatThread.ID(UUID())
            let pastaThread = ChatThread.ID(UUID())

            try await database.write { db in
                try ChatThread.insert { ChatThread(id: swiftThread, title: "Swift talk") }.execute(db)
                try ChatThread.insert { ChatThread(id: pastaThread, title: "Dinner") }.execute(db)
                try ChatMessage.insert {
                    ChatMessage(
                        id: ChatMessage.ID(UUID()),
                        threadID: swiftThread,
                        role: .assistant,
                        content: "Actors serialize access to mutable state."
                    )
                }
                .execute(db)
                try ChatMessage.insert {
                    ChatMessage(
                        id: ChatMessage.ID(UUID()),
                        threadID: pastaThread,
                        role: .user,
                        content: "How long do I boil rigatoni?"
                    )
                }
                .execute(db)
            }

            let hits = try await database.read { db in
                try MessageSearch.hits(matching: "actors").fetchAll(db)
            }

            #expect(hits.count == 1)
            #expect(hits.first?.threadID == swiftThread)
            #expect(hits.first?.title == "Swift talk")
            #expect(hits.first?.snippet.localizedCaseInsensitiveContains("actors") == true)
        }
    }

    @Test("Matches on a prefix, not just whole words")
    func prefixMatch() async throws {
        try await withDependencies {
            try $0.bootstrapDatabase()
        } operation: {
            @Dependency(\.defaultDatabase) var database
            let thread = ChatThread.ID(UUID())

            try await database.write { db in
                try ChatThread.insert { ChatThread(id: thread, title: "Notes") }.execute(db)
                try ChatMessage.insert {
                    ChatMessage(
                        id: ChatMessage.ID(UUID()),
                        threadID: thread,
                        role: .user,
                        content: "Explain notarization for macOS apps"
                    )
                }
                .execute(db)
            }

            let hits = try await database.read { db in
                try MessageSearch.hits(matching: "notariz").fetchAll(db)
            }
            #expect(hits.count == 1)
        }
    }

    @Test("Deleting a thread removes its messages from the index")
    func deleteRemovesFromIndex() async throws {
        try await withDependencies {
            try $0.bootstrapDatabase()
        } operation: {
            @Dependency(\.defaultDatabase) var database
            let thread = ChatThread.ID(UUID())

            try await database.write { db in
                try ChatThread.insert { ChatThread(id: thread, title: "Temp") }.execute(db)
                try ChatMessage.insert {
                    ChatMessage(
                        id: ChatMessage.ID(UUID()),
                        threadID: thread,
                        role: .user,
                        content: "unicorn sightings"
                    )
                }
                .execute(db)
            }
            try await database.write { db in
                try ChatThread.find(thread).delete().execute(db)
            }

            let hits = try await database.read { db in
                try MessageSearch.hits(matching: "unicorn").fetchAll(db)
            }
            #expect(hits.isEmpty)
        }
    }

    @Test("Recent threads exclude ones with no messages")
    func recentSkipsEmpty() async throws {
        try await withDependencies {
            try $0.bootstrapDatabase()
        } operation: {
            @Dependency(\.defaultDatabase) var database
            let used = ChatThread.ID(UUID())
            let empty = ChatThread.ID(UUID())

            try await database.write { db in
                try ChatThread.insert { ChatThread(id: used, title: "Used") }.execute(db)
                try ChatThread.insert { ChatThread(id: empty, title: "Empty") }.execute(db)
                try ChatMessage.insert {
                    ChatMessage(id: ChatMessage.ID(UUID()), threadID: used, role: .user, content: "hello")
                }
                .execute(db)
            }

            let hits = try await database.read { db in
                try MessageSearch.recent().fetchAll(db)
            }
            #expect(hits.map(\.threadID) == [used])
        }
    }
}

@Suite("Palette state")
struct CommandPaletteStateTests {
    private func state(_ titles: [String]) -> CommandPaletteState {
        var state = CommandPaletteState()
        state.hits = IdentifiedArrayOf(
            uniqueElements: titles.map {
                SearchHit(threadID: ChatThread.ID(UUID()), title: $0, snippet: "", updatedAt: Date())
            }
        )
        state.highlighted = state.hits.first?.id
        return state
    }

    @Test("Highlight wraps around both ends")
    func wraps() {
        var state = self.state(["a", "b", "c"])
        state.moveHighlight(-1)
        #expect(state.highlightedHit?.title == "c")
        state.moveHighlight(1)
        #expect(state.highlightedHit?.title == "a")
    }

    @Test("Moving with no results clears the highlight")
    func empty() {
        var state = CommandPaletteState()
        state.moveHighlight(1)
        #expect(state.highlighted == nil)
    }

    @Test("A highlight that vanishes from the results does not select a stranger")
    func staleHighlight() {
        var state = self.state(["a", "b"])
        let stale = state.highlighted
        state.hits = []
        #expect(state.highlightedHit == nil)
        #expect(stale != nil)
    }
}

@Suite("Titles")
struct TitleTests {
    @Test("Model titles are stripped of quotes and trailing punctuation")
    func cleans() {
        #expect(FlareModel.cleanTitle("  \"Swift Concurrency Basics.\"  ") == "Swift Concurrency Basics")
    }

    @Test("Fallback titles cut at a word boundary")
    func fallback() {
        let long = String(repeating: "alpha ", count: 40)
        let title = FlareModel.fallbackTitle(long)
        #expect(title.hasSuffix("…"))
        #expect(title.count <= 61)
    }

    @Test("A short prompt is used whole")
    func shortPrompt() {
        #expect(FlareModel.fallbackTitle("Hello there") == "Hello there")
    }
}

@Suite("Search tuning")
struct SearchTuningTests {
    @Test("Low Power Mode does less work per keystroke")
    func lowPowerIsCheaper() {
        #expect(SearchTuning.lowPower.debounce > SearchTuning.standard.debounce)
        #expect(SearchTuning.lowPower.matchLimit < SearchTuning.standard.matchLimit)
        #expect(SearchTuning.lowPower.resultLimit < SearchTuning.standard.resultLimit)
    }

    @Test("Ranking a candidate list at least as long as the result list")
    func limitsAreCoherent() {
        for tuning in [SearchTuning.standard, .lowPower] {
            #expect(tuning.matchLimit >= tuning.resultLimit)
        }
    }
}
