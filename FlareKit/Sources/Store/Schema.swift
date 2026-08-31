import Dependencies
import Foundation
import SQLiteData
import Tagged

@Table
public struct ChatThread: Identifiable, Equatable, Sendable {
    public typealias ID = Tagged<Self, UUID>

    public let id: ID
    public var title = ""
    public var createdAt = Date()
    public var updatedAt = Date()
    public var model = ChatModelCatalog.default.id

    public init(
        id: ID,
        title: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        model: String = ChatModelCatalog.default.id
    ) {
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
    public typealias ID = Tagged<Self, UUID>

    public let id: ID
    public var threadID: ChatThread.ID
    public var role: Role
    public var content = ""
    public var reasoning = ""
    public var imageFile = ""
    public var createdAt = Date()

    public enum Role: String, QueryBindable, Sendable {
        case user
        case assistant
    }

    public init(
        id: ID,
        threadID: ChatThread.ID,
        role: Role,
        content: String = "",
        reasoning: String = "",
        imageFile: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadID = threadID
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.imageFile = imageFile
        self.createdAt = createdAt
    }
}

public extension DependencyValues {
    mutating func bootstrapDatabase() throws {
        let directory = URL.applicationSupportDirectory.appending(path: "Flare", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // An explicit path: the library default is a Mac-wide SQLiteData.db that any
        // other SQLiteData app shares and that DEBUG's erase-on-schema-change wipes.
        let database = try SQLiteData.defaultDatabase(
            path: directory.appending(path: "chats.db").path(percentEncoded: false)
        )
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

        // Not porter: it indexes stems, so a prefix query ("notariz") misses its stem ("notar").
        migrator.registerMigration("Full-text search over messages") { db in
            try #sql(
                """
                CREATE VIRTUAL TABLE "messageSearch" USING fts5(
                  "messageID" UNINDEXED,
                  "threadID" UNINDEXED,
                  "content",
                  tokenize = 'unicode61 remove_diacritics 2'
                )
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TRIGGER "messageSearch_insert" AFTER INSERT ON "chatMessages" BEGIN
                  INSERT INTO "messageSearch" ("messageID", "threadID", "content")
                  VALUES (new."id", new."threadID", new."content");
                END
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TRIGGER "messageSearch_delete" AFTER DELETE ON "chatMessages" BEGIN
                  DELETE FROM "messageSearch" WHERE "messageID" = old."id";
                END
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TRIGGER "messageSearch_update" AFTER UPDATE OF "content" ON "chatMessages" BEGIN
                  DELETE FROM "messageSearch" WHERE "messageID" = old."id";
                  INSERT INTO "messageSearch" ("messageID", "threadID", "content")
                  VALUES (new."id", new."threadID", new."content");
                END
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Generated images") { db in
            try #sql(
                """
                ALTER TABLE "chatMessages" ADD COLUMN "imageFile" TEXT NOT NULL DEFAULT ''
                """
            )
            .execute(db)
        }

        try migrator.migrate(database)
        defaultDatabase = database
    }
}
