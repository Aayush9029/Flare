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
    @ObservationIgnored @Dependency(\.windowClient) private var windowClient
    @ObservationIgnored @Dependency(\.imageStore) private var imageStore
    @ObservationIgnored @Dependency(\.uuid) private var uuid
    @ObservationIgnored @Dependency(\.date.now) private var now

    public let preferences = Preferences()
    public let license = LicenseModel()
    public let providers: ProviderCatalog

    public var statusPlaceholder: String {
        if isGeneratingImage { return "Drawing…" }
        if isSearchingWeb { return "Searching the web…" }
        return isStreaming ? "Responding…" : "Ask anything"
    }

    /// Which provider answers right now, shown next to the assistant name.
    public var responseSource: String {
        providers.active.name
    }

    public var selectedThreadID: ChatThread.ID?
    public var draft = ""
    /// Images dropped or pasted into the composer, sent with the next message.
    public private(set) var attachments: [Data] = []
    /// Messages sent while a reply was streaming. They go out in order as replies finish.
    public private(set) var queue: [QueuedMessage] = []

    public var queuedForCurrentThread: [QueuedMessage] {
        queue.filter { $0.threadID == selectedThreadID }
    }
    public var errorMessage: String?

    public private(set) var liveResponse: MarkdownRelay?
    public private(set) var liveReasoning: MarkdownRelay?
    public private(set) var isStreaming = false
    public private(set) var isSearchingWeb = false
    public private(set) var isGeneratingImage = false
    public private(set) var liveCitations: [Citation] = []
    /// The answer being streamed, or the last one that landed. The transcript keeps
    /// this row until the stored message arrives, so the answer never blinks out.
    public private(set) var liveMessage: ChatMessage?
    public private(set) var liveHasReasoning = false
    /// Thinking runs from the first reasoning delta to the first answer delta.
    public private(set) var liveReasoningStartedAt: Date?
    public private(set) var liveReasoningEndedAt: Date?
    @ObservationIgnored private var relays: [ChatMessage.ID: MessageRelays] = [:]

    public private(set) var palette = CommandPaletteState()
    /// The message whose reasoning fills the panel, until Escape or the close button.
    public private(set) var presentedReasoning: ChatMessage?
    public private(set) var isModelPickerPresented = false

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var paletteGeneration = 0

    public init() {
        providers = ProviderCatalog(preferences: preferences)
    }

    public func toggle() {
        guard windowClient.isVisible() else { return open() }
        // Pinned on top, the panel stays visible after another app takes the keyboard.
        // The hotkey then brings focus back rather than closing it.
        if windowClient.isKey() {
            hide()
        } else {
            windowClient.show()
        }
    }

    public var isPanelVisible: Bool { windowClient.isVisible() }

    public func open() {
        if preferences.newThreadOnOpen || selectedThreadID == nil {
            newThread()
        }
        windowClient.show()
    }

    public func showReasoning(for message: ChatMessage) {
        presentedReasoning = message
    }

    public func toggleModelPicker() {
        isModelPickerPresented.toggle()
    }

    public func dismissModelPicker() {
        isModelPickerPresented = false
    }

    public func dismissReasoning() {
        presentedReasoning = nil
    }

    public func hide() {
        closePalette()
        presentedReasoning = nil
        isModelPickerPresented = false
        windowClient.hide()
    }

    public func newThread() {
        cancelStreaming()
        let previous = selectedThreadID
        let thread = ChatThread(id: ChatThread.ID(uuid()), createdAt: now, updatedAt: now, model: providers.selection.model)
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

    public func addAttachment(_ image: Data) {
        attachments.append(image)
    }

    public func removeAttachment(at index: Int) {
        guard attachments.indices.contains(index) else { return }
        attachments.remove(at: index)
    }

    public func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty || !attachments.isEmpty, let threadID = selectedThreadID else { return }
        if isStreaming {
            queue.append(QueuedMessage(id: uuid(), threadID: threadID, text: prompt, attachments: attachments))
            draft = ""
            attachments = []
            return
        }
        // Cleared only once the send is under way, so a refused send keeps the text.
        guard dispatch(prompt: prompt, attachments: attachments, threadID: threadID) else { return }
        draft = ""
        attachments = []
    }

    public func removeFromQueue(_ id: UUID) {
        queue.removeAll { $0.id == id }
    }

    /// Sends the next queued message for the current thread, if nothing is streaming.
    public func sendNextQueued() {
        guard !isStreaming, let threadID = selectedThreadID,
              let index = queue.firstIndex(where: { $0.threadID == threadID })
        else { return }
        let item = queue.remove(at: index)
        if !dispatch(prompt: item.text, attachments: item.attachments, threadID: threadID) {
            queue.insert(item, at: index)
        }
    }

    /// Starts a turn, or reports why it cannot and returns false with nothing changed.
    @discardableResult
    private func dispatch(prompt: String, attachments: [Data], threadID: ChatThread.ID) -> Bool {
        guard license.isUnlocked else {
            errorMessage = "Your free trial has ended. Open Settings to buy Flare for $9.99."
            return false
        }
        guard providers.active.isReady else {
            errorMessage = providers.active.setupMessage
            return false
        }
        errorMessage = nil

        let imageFiles = attachments.compactMap { image in
            withErrorReporting { try imageStore.save(image) }
        }
        let userMessage = ChatMessage(
            id: ChatMessage.ID(uuid()),
            threadID: threadID,
            role: .user,
            content: prompt,
            imageFile: imageFiles.joined(separator: "|"),
            createdAt: now
        )
        withErrorReporting {
            try database.write { db in
                try ChatMessage.insert { userMessage }.execute(db)
                try ChatThread.find(threadID).update { $0.updatedAt = now }.execute(db)
            }
        }

        liveCitations = []
        let messageID = ChatMessage.ID(uuid())
        liveMessage = ChatMessage(id: messageID, threadID: threadID, role: .assistant, createdAt: now)
        liveHasReasoning = false
        liveReasoningStartedAt = nil
        liveReasoningEndedAt = nil
        let response = MarkdownRelay()
        let reasoning = MarkdownRelay()
        liveResponse = response
        liveReasoning = reasoning
        isStreaming = true

        streamTask = Task { [weak self] in
            await self?.runStream(threadID: threadID, messageID: messageID, response: response, reasoning: reasoning)
        }
        return true
    }

    private func runStream(
        threadID: ChatThread.ID,
        messageID: ChatMessage.ID,
        response: MarkdownRelay,
        reasoning: MarkdownRelay
    ) async {
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
        let imageStore = imageStore
        do {
            turns = try await database.read { db in
                try ChatMessage
                    .where { $0.threadID.eq(threadID) }
                    .order { $0.createdAt.asc() }
                    .fetchAll(db)
                    .map { message in
                        ChatTurn(
                            role: message.role.rawValue,
                            text: message.content,
                            images: message.role == .user ? Self.attachedImages(of: message, in: imageStore) : []
                        )
                    }
            }
        } catch {
            errorMessage = error.localizedDescription
            endStream()
            return
        }

        let provider = providers.active
        let selection = providers.selection
        let webSearch = preferences.webSearchEnabled && provider.supportsWebSearch
        var wasStopped = false
        do {
            let events = try await chatClient.stream(
                ChatRequest(
                    endpoint: provider.endpoint,
                    model: selection.model,
                    effort: selection.effort,
                    instructions: Self.instructions(prompt: preferences.systemPrompt, webSearch: webSearch),
                    turns: turns,
                    webSearch: webSearch,
                    imageGeneration: preferences.imagesEnabled && provider.supportsImageGeneration
                )
            )
            for try await event in events {
                switch event {
                case .outputTextDelta(let delta):
                    response.append(delta)
                    if liveReasoningStartedAt != nil, liveReasoningEndedAt == nil { liveReasoningEndedAt = now }
                case .reasoningSummaryDelta(let delta):
                    reasoning.append(delta)
                    if !liveHasReasoning {
                        liveHasReasoning = true
                        liveReasoningStartedAt = now
                    }
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
            wasStopped = true
        } catch {
            errorMessage = error.localizedDescription
        }

        let text = response.text
        guard !text.isEmpty || !imageFile.isEmpty else {
            liveMessage = nil
            endStream()
            return
        }
        if liveReasoningStartedAt != nil, liveReasoningEndedAt == nil { liveReasoningEndedAt = now }
        let reasoningSeconds = zip(liveReasoningStartedAt, liveReasoningEndedAt).map { $1.timeIntervalSince($0) } ?? 0
        let assistantMessage = ChatMessage(
            id: messageID,
            threadID: threadID,
            role: .assistant,
            content: text,
            reasoning: reasoning.text,
            reasoningSeconds: reasoningSeconds,
            imageFile: imageFile,
            createdAt: now
        )
        withErrorReporting {
            try database.write { db in
                try ChatMessage.insert { assistantMessage }.execute(db)
                try ChatThread.find(threadID).update { $0.updatedAt = now }.execute(db)
            }
        }
        relays[messageID] = MessageRelays(response: response, reasoning: reasoning)
        liveMessage = assistantMessage
        endStream()
        // A stopped reply leaves the queue waiting; a finished one lets it move.
        if !wasStopped { sendNextQueued() }

        await generateTitleIfNeeded(threadID, prompt: turns.last?.text ?? "", answer: text)
    }

    public func stopStreaming() {
        cancelStreaming()
    }

    /// The files a user message carries, `|`-separated in `imageFile`.
    public nonisolated static func attachedImages(of message: ChatMessage, in store: ImageStore) -> [Data] {
        message.imageFile.split(separator: "|").compactMap { name in
            store.url(String(name)).flatMap { try? Data(contentsOf: $0) }
        }
    }

    /// The relay behind a message's Markdown view. The relay that streamed an answer
    /// stays in service once it is stored, so the view that rendered it keeps its
    /// parsed document instead of starting over from the saved text.
    public func responseRelay(for message: ChatMessage) -> MarkdownRelay {
        if message.id == liveMessage?.id, let liveResponse { return liveResponse }
        return storedRelays(for: message).response
    }

    public func reasoningRelay(for message: ChatMessage) -> MarkdownRelay {
        if message.id == liveMessage?.id, let liveReasoning { return liveReasoning }
        return storedRelays(for: message).reasoning
    }

    private func storedRelays(for message: ChatMessage) -> MessageRelays {
        if let cached = relays[message.id] { return cached }
        let created = MessageRelays(
            response: .finished(message.content),
            reasoning: .finished(message.reasoning)
        )
        relays[message.id] = created
        return created
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
        let provider = providers.active
        let cheapest = provider.titleSelection(current: providers.selection)
        let generated = try? await chatClient.complete(
            ChatRequest(
                endpoint: provider.endpoint,
                model: cheapest.model,
                effort: cheapest.effort,
                instructions: "You write short, specific titles. No quotes, no trailing punctuation.",
                turns: [
                    ChatTurn(
                        role: "user",
                        text: """
                        Title this conversation in 3 to 6 words. Reply with the title only.

                        User: \(prompt.prefix(500))
                        Assistant: \(answer.prefix(500))
                        """
                    )
                ]
            )
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

public struct QueuedMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let threadID: ChatThread.ID
    public let text: String
    public let attachments: [Data]

    public init(id: UUID, threadID: ChatThread.ID, text: String, attachments: [Data]) {
        self.id = id
        self.threadID = threadID
        self.text = text
        self.attachments = attachments
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

private struct MessageRelays {
    let response: MarkdownRelay
    let reasoning: MarkdownRelay
}

private func zip<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
