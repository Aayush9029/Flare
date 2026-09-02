import Foundation

public struct ChatRequest: Sendable, Equatable {
    public var endpoint: ChatEndpoint
    public var model: String
    /// Nil sends no reasoning parameter at all.
    public var effort: String?
    public var instructions: String
    public var turns: [ChatTurn]
    public var webSearch: Bool
    public var imageGeneration: Bool
    public var sessionID: UUID

    public init(
        endpoint: ChatEndpoint,
        model: String,
        effort: String?,
        instructions: String,
        turns: [ChatTurn],
        webSearch: Bool = false,
        imageGeneration: Bool = false,
        sessionID: UUID = UUID()
    ) {
        self.endpoint = endpoint
        self.model = model
        self.effort = effort
        self.instructions = instructions
        self.turns = turns
        self.webSearch = webSearch
        self.imageGeneration = imageGeneration
        self.sessionID = sessionID
    }
}
