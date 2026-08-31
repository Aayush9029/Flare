import AppKit
import Dependencies
import Foundation
import IssueReporting
import SQLiteData

@MainActor
@Observable
public final class FlareModel {
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database
    @ObservationIgnored @Dependency(\.chatClient) private var chatClient
    @ObservationIgnored @Dependency(\.openAIAuth) private var auth
    @ObservationIgnored @Dependency(\.windowClient) private var windowClient
    @ObservationIgnored @Dependency(\.uuid) private var uuid
    @ObservationIgnored @Dependency(\.date.now) private var now

    public let preferences = Preferences()

    public var selectedThreadID: ChatThread.ID?
    public var draft = ""
    public var errorMessage: String?
    public var isSidebarVisible = true

    /// Non-nil only while a response streams.
    public private(set) var liveResponse: MarkdownRelay?
    public private(set) var liveReasoning: MarkdownRelay?
    public private(set) var isStreaming = false

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private let sessionID = UUID()

    public init() {}

    // MARK: - Panel

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
        windowClient.hide()
    }

    // MARK: - Threads

    public func newThread() {
        cancelStreaming()
        let thread = ChatThread(id: uuid(), createdAt: now, updatedAt: now, model: preferences.selectedModel)
        withErrorReporting {
            try database.write { db in
                try ChatThread.insert { thread }.execute(db)
            }
        }
        selectedThreadID = thread.id
        draft = ""
        errorMessage = nil
    }

    public func selectThread(_ id: ChatThread.ID) {
        guard id != selectedThreadID else { return }
        cancelStreaming()
        selectedThreadID = id
        errorMessage = nil
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

    /// Removes a thread that was opened but never used, so the sidebar stays clean.
    public func discardEmptyThread(_ id: ChatThread.ID) {
        withErrorReporting {
            try database.write { db in
                let count = try ChatMessage.where { $0.threadID.eq(id) }.fetchCount(db)
                guard count == 0 else { return }
                try ChatThread.find(id).delete().execute(db)
            }
        }
    }

    private func mostRecentThreadID() -> ChatThread.ID? {
        try? database.read { db in
            try ChatThread.order { $0.updatedAt.desc() }.limit(1).fetchOne(db)?.id
        }
    }

    // MARK: - Sending

    public func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming else { return }
        guard auth.isSignedIn() else {
            errorMessage = AuthError.notSignedIn.localizedDescription
            return
        }
        guard let threadID = selectedThreadID else { return }

        draft = ""
        errorMessage = nil

        let userMessage = ChatMessage(id: uuid(), threadID: threadID, role: .user, content: prompt, createdAt: now)
        withErrorReporting {
            try database.write { db in
                try ChatMessage.insert { userMessage }.execute(db)
                try ChatThread
                    .find(threadID)
                    .update { $0.updatedAt = now }
                    .execute(db)
            }
        }
        titleThreadIfNeeded(threadID, from: prompt)

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
        defer {
            response.finish()
            reasoning.finish()
            isStreaming = false
            liveResponse = nil
            liveReasoning = nil
        }

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
            return
        }

        do {
            let events = try await chatClient.stream(
                turns,
                preferences.selectedModel,
                preferences.effectiveEffort,
                preferences.systemPrompt,
                sessionID
            )
            for try await event in events {
                switch event {
                case .outputTextDelta(let delta): response.append(delta)
                case .reasoningSummaryDelta(let delta): reasoning.append(delta)
                case .failed(let message): errorMessage = message
                case .completed: break
                }
            }
        } catch is CancellationError {
            // Leave whatever streamed so far on screen.
        } catch {
            errorMessage = error.localizedDescription
        }

        let text = response.text
        guard !text.isEmpty else { return }
        let assistantMessage = ChatMessage(
            id: uuid(),
            threadID: threadID,
            role: .assistant,
            content: text,
            reasoning: reasoning.text,
            createdAt: now
        )
        withErrorReporting {
            try database.write { db in
                try ChatMessage.insert { assistantMessage }.execute(db)
                try ChatThread.find(threadID).update { $0.updatedAt = now }.execute(db)
            }
        }
    }

    public func stopStreaming() {
        cancelStreaming()
    }

    private func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
    }

    /// The first prompt names the thread; long prompts are cut at a word boundary.
    private func titleThreadIfNeeded(_ id: ChatThread.ID, from prompt: String) {
        withErrorReporting {
            try database.write { db in
                guard let thread = try ChatThread.find(id).fetchOne(db), thread.title.isEmpty else { return }
                let title = String(prompt.prefix(60))
                let trimmed = title.count < prompt.count
                    ? (title.split(separator: " ").dropLast().joined(separator: " ") + "…")
                    : title
                try ChatThread.find(id).update { $0.title = trimmed }.execute(db)
            }
        }
    }
}
