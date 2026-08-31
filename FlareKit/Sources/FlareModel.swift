import AppKit
import Dependencies
import Foundation
import IdentifiedCollections
import IssueReporting
import SQLiteData

@MainActor
@Observable
public final class FlareModel {
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database
    @ObservationIgnored @Dependency(\.chatClient) private var chatClient
    @ObservationIgnored @Dependency(\.openAIAuth) private var auth
    @ObservationIgnored @Dependency(\.windowClient) private var windowClient
    @ObservationIgnored @Dependency(\.imageStore) private var imageStore
    @ObservationIgnored @Dependency(\.uuid) private var uuid
    @ObservationIgnored @Dependency(\.date.now) private var now

    public let preferences = Preferences()
    public let license = LicenseModel()

    public var statusPlaceholder: String {
        if isGeneratingImage { return "Drawing…" }
        if isSearchingWeb { return "Searching the web…" }
        return isStreaming ? "Thinking…" : "Ask anything"
    }

    /// Which credential answers right now, shown next to the assistant name.
    public var responseSource: String {
        switch preferences.credentialPreference {
        case .chatgpt: "Codex"
        case .apiKey: "API key"
        case .automatic: auth.currentAPIKey() == nil ? "Codex" : "API key"
        }
    }

    public var selectedThreadID: ChatThread.ID?
    public var draft = ""
    public var errorMessage: String?

    public private(set) var liveResponse: MarkdownRelay?
    public private(set) var liveReasoning: MarkdownRelay?
    public private(set) var isStreaming = false
    public private(set) var isSearchingWeb = false
    public private(set) var isGeneratingImage = false
    public private(set) var liveCitations: [Citation] = []

    public private(set) var palette = CommandPaletteState()

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var paletteGeneration = 0

    public init() {}

    public func toggle() {
        if windowClient.isVisible() {
            hide()
        } else {
            open()
        }
    }

    public func open() {
        if preferences.newThreadOnOpen || selectedThreadID == nil {
            newThread()
        }
        windowClient.show()
    }

    public func hide() {
        closePalette()
        windowClient.hide()
    }

    public func newThread() {
        cancelStreaming()
        let previous = selectedThreadID
        let thread = ChatThread(id: ChatThread.ID(uuid()), createdAt: now, updatedAt: now, model: preferences.selectedModel)
        withErrorReporting {
            try database.write { db in
                try ChatThread.insert { thread }.execute(db)
            }
        }
        selectedThreadID = thread.id
        draft = ""
        errorMessage = nil
        if let previous { discardEmptyThread(previous) }
    }

    public func selectThread(_ id: ChatThread.ID) {
        guard id != selectedThreadID else { return }
        cancelStreaming()
        let previous = selectedThreadID
        selectedThreadID = id
        errorMessage = nil
        if let previous { discardEmptyThread(previous) }
    }

    public func deleteThread(_ id: ChatThread.ID) {
        if id == selectedThreadID { cancelStreaming() }
        withErrorReporting {
            try database.write { db in
                try ChatThread.find(id).delete().execute(db)
            }
        }
        guard id == selectedThreadID else { return }
        selectedThreadID = mostRecentThreadID()
        if selectedThreadID == nil { newThread() }
    }

    public func discardEmptyThread(_ id: ChatThread.ID) {
        guard !isStreaming else { return }
        var deleted = false
        withErrorReporting {
            try database.write { db in
                let count = try ChatMessage.where { $0.threadID.eq(id) }.fetchCount(db)
                guard count == 0 else { return }
                try ChatThread.find(id).delete().execute(db)
                deleted = true
            }
        }
        // Leaving the id selected would point every later write at a missing row.
        if deleted, id == selectedThreadID { selectedThreadID = nil }
    }

    private func mostRecentThreadID() -> ChatThread.ID? {
        try? database.read { db in
            try ChatThread.order { $0.updatedAt.desc() }.limit(1).fetchOne(db)?.id
        }
    }

    public func togglePalette() {
        palette.isPresented ? closePalette() : openPalette()
    }

    public func openPalette() {
        palette.isPresented = true
        palette.query = ""
        palette.highlighted = nil
        refreshPalette()
    }

    public func closePalette() {
        searchTask?.cancel()
        palette.isPresented = false
        palette.query = ""
        palette.hits = []
    }

    public func updatePaletteQuery(_ query: String) {
        palette.query = query
        refreshPalette()
    }

    public func movePaletteHighlight(_ offset: Int) {
        palette.moveHighlight(offset)
    }

    public func commitPaletteSelection() {
        guard palette.hits.isEmpty == false, let hit = palette.highlightedHit else {
            closePalette()
            return
        }
        closePalette()
        selectThread(hit.threadID)
    }

    public func refreshPaletteResults() {
        refreshPalette()
    }

    private func refreshPalette() {
        searchTask?.cancel()
        let query = palette.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tuning = SearchTuning.current
        paletteGeneration += 1
        let generation = paletteGeneration
        searchTask = Task { [weak self] in
            guard let self else { return }
            if !query.isEmpty {
                try? await Task.sleep(for: tuning.debounce)
                guard !Task.isCancelled else { return }
            }
            let hits = (try? await database.read { db in
                query.isEmpty
                    ? try MessageSearch.recent(limit: tuning.resultLimit).fetchAll(db)
                    : try MessageSearch.hits(
                        matching: query,
                        limit: tuning.resultLimit,
                        matchLimit: tuning.matchLimit
                    )
                    .fetchAll(db)
            }) ?? []
            guard !Task.isCancelled, generation == paletteGeneration else { return }
            palette.hits = IdentifiedArrayOf(uniqueElements: hits)
            palette.highlighted = hits.first?.id
        }
    }

    public func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming else { return }
        guard license.isUnlocked else {
            errorMessage = "Flare needs a license key. Open Settings to buy or activate one."
            return
        }
        guard auth.isSignedIn() else {
            errorMessage = AuthError.notSignedIn.localizedDescription
            return
        }
        guard let threadID = selectedThreadID else { return }

        draft = ""
        errorMessage = nil

        let userMessage = ChatMessage(id: ChatMessage.ID(uuid()), threadID: threadID, role: .user, content: prompt, createdAt: now)
        withErrorReporting {
            try database.write { db in
                try ChatMessage.insert { userMessage }.execute(db)
                try ChatThread.find(threadID).update { $0.updatedAt = now }.execute(db)
            }
        }

        liveCitations = []
        let response = MarkdownRelay()
        let reasoning = MarkdownRelay()
        liveResponse = response
        liveReasoning = reasoning
        isStreaming = true

        streamTask = Task { [weak self] in
            await self?.runStream(threadID: threadID, response: response, reasoning: reasoning)
        }
    }

    private func runStream(threadID: ChatThread.ID, response: MarkdownRelay, reasoning: MarkdownRelay) async {
        func endStream() {
            response.finish()
            reasoning.finish()
            isStreaming = false
            isSearchingWeb = false
            isGeneratingImage = false
            liveResponse = nil
            liveReasoning = nil
        }

        var imageFile = ""
        let turns: [ChatTurn]
        do {
            turns = try await database.read { db in
                try ChatMessage
                    .where { $0.threadID.eq(threadID) }
                    .order { $0.createdAt.asc() }
                    .fetchAll(db)
                    .map { ChatTurn(role: $0.role.rawValue, text: $0.content) }
            }
        } catch {
            errorMessage = error.localizedDescription
            endStream()
            return
        }

        do {
            let events = try await chatClient.stream(
                turns,
                preferences.selectedModel,
                preferences.effectiveEffort,
                Self.instructions(
                    prompt: preferences.systemPrompt,
                    webSearch: preferences.webSearchEnabled
                ),
                Self.tools(webSearch: preferences.webSearchEnabled, images: preferences.imagesEnabled),
                preferences.credentialPreference,
                UUID()
            )
            for try await event in events {
                switch event {
                case .outputTextDelta(let delta): response.append(delta)
                case .reasoningSummaryDelta(let delta): reasoning.append(delta)
                case .imageGenerationStarted: isGeneratingImage = true
                case .image(let data):
                    isGeneratingImage = false
                    withErrorReporting { imageFile = try imageStore.save(data) }
                case .webSearchStarted: isSearchingWeb = true
                case .webSearchFinished: isSearchingWeb = false
                case .citation(let citation):
                    if !liveCitations.contains(citation) { liveCitations.append(citation) }
                case .failed(let message): errorMessage = message
                case .completed: break
                }
            }
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }

        let text = response.text
        guard !text.isEmpty || !imageFile.isEmpty else {
            endStream()
            return
        }
        let assistantMessage = ChatMessage(
            id: ChatMessage.ID(uuid()),
            threadID: threadID,
            role: .assistant,
            content: text,
            reasoning: reasoning.text,
            imageFile: imageFile,
            createdAt: now
        )
        withErrorReporting {
            try database.write { db in
                try ChatMessage.insert { assistantMessage }.execute(db)
                try ChatThread.find(threadID).update { $0.updatedAt = now }.execute(db)
            }
        }
        endStream()

        await generateTitleIfNeeded(threadID, prompt: turns.last?.text ?? "", answer: text)
    }

    public func stopStreaming() {
        cancelStreaming()
    }

    private func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
    }

    private func generateTitleIfNeeded(_ id: ChatThread.ID, prompt: String, answer: String) async {
        let isUntitled = (try? await database.read { db in
            try ChatThread.find(id).fetchOne(db)?.title.isEmpty
        }) ?? false
        guard isUntitled == true else { return }

        var title = Self.fallbackTitle(prompt)
        let generated = try? await chatClient.complete(
            turns: [
                ChatTurn(
                    role: "user",
                    text: """
                    Title this conversation in 3 to 6 words. Reply with the title only.

                    User: \(prompt.prefix(500))
                    Assistant: \(answer.prefix(500))
                    """
                )
            ],
            model: ChatModelCatalog.titleModel.id,
            instructions: "You write short, specific titles. No quotes, no trailing punctuation."
        )
        if let generated {
            let cleaned = Self.cleanTitle(generated)
            if !cleaned.isEmpty { title = cleaned }
        }

        withErrorReporting {
            try database.write { db in
                try ChatThread.find(id).update { $0.title = title }.execute(db)
            }
        }
    }

    /// Appended at request time rather than baked into the editable prompt, so a
    /// custom prompt keeps working and the toggle takes effect immediately.
    nonisolated static func tools(webSearch: Bool, images: Bool) -> [ResponsesAPI.Tool] {
        var tools: [ResponsesAPI.Tool] = []
        if webSearch { tools.append(.webSearch) }
        if images { tools.append(.imageGeneration) }
        return tools
    }

    nonisolated static func instructions(prompt: String, webSearch: Bool) -> String {
        guard webSearch else { return prompt }
        return """
        \(prompt)

        You have a web_search tool. Use it without being asked whenever the answer         depends on current, recent, or verifiable facts: news, prices, versions,         releases, schedules, people, products, documentation, or anything after your         training cutoff. Prefer searching over guessing or hedging about staleness.         Cite the source inline as a Markdown link. Do not search for arithmetic,         definitions, writing help, or anything you already know reliably.
        """
    }

    nonisolated static func cleanTitle(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”.,;:"))
        return String(trimmed.prefix(60))
    }

    nonisolated static func fallbackTitle(_ prompt: String) -> String {
        let head = String(prompt.prefix(60))
        guard head.count < prompt.count else { return head }
        return head.split(separator: " ").dropLast().joined(separator: " ") + "…"
    }
}

public struct CommandPaletteState: Equatable, Sendable {
    public var isPresented = false
    public var query = ""
    public var hits: IdentifiedArrayOf<SearchHit> = []
    public var highlighted: SearchHit.ID?

    public init() {}

    public var highlightedHit: SearchHit? {
        highlighted.flatMap { hits[id: $0] }
    }

    mutating func moveHighlight(_ offset: Int) {
        guard !hits.isEmpty else {
            highlighted = nil
            return
        }
        let current = highlighted.flatMap { hits.index(id: $0) } ?? 0
        let next = (current + offset + hits.count) % hits.count
        highlighted = hits[next].id
    }
}
