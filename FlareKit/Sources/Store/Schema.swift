import Dependencies
import Foundation
import SQLiteData

@Table
public struct ChatThread: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title = ""
    public var createdAt = Date()
    public var updatedAt = Date()
    public var model = ChatModelCatalog.default.id

    public init(id: UUID, title: String = "", createdAt: Date = Date(), updatedAt: Date = Date(), model: String = ChatModelCatalog.default.id) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.model = model
    }

    public var displayTitle: String {
        title.isEmpty ? "New Chat" : title
    }
}

@Table
public struct ChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var threadID: ChatThread.ID
    public var role: Role
    public var content = ""
    public var reasoning = ""
    public var createdAt = Date()

    public enum Role: String, QueryBindable, Sendable {
        case user
        case assistant
    }

    public init(
        id: UUID,
        threadID: ChatThread.ID,
        role: Role,
        content: String = "",
        reasoning: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.createdAt = createdAt
    }
}

public extension DependencyValues {
    mutating func bootstrapDatabase() throws {
        let database = try SQLiteData.defaultDatabase()
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("Create threads and messages") { db in
            try #sql(
                """
                CREATE TABLE "chatThreads" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "title" TEXT NOT NULL DEFAULT '',
                  "createdAt" TEXT NOT NULL,
                  "updatedAt" TEXT NOT NULL,
                  "model" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TABLE "chatMessages" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "threadID" TEXT NOT NULL REFERENCES "chatThreads"("id") ON DELETE CASCADE,
                  "role" TEXT NOT NULL,
                  "content" TEXT NOT NULL DEFAULT '',
                  "reasoning" TEXT NOT NULL DEFAULT '',
                  "createdAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE INDEX "chatMessages_threadID" ON "chatMessages"("threadID", "createdAt")
                """
            )
            .execute(db)
        }
        try migrator.migrate(database)
        defaultDatabase = database
    }
}
