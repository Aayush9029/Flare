import Foundation
import IdentifiedCollections
import SQLiteData
import Tagged

@Selection
public struct SearchHit: Identifiable, Equatable, Sendable {
    public let threadID: ChatThread.ID
    public let title: String
    public let snippet: String
    public let updatedAt: Date

    public var id: ChatThread.ID { threadID }

    public var displayTitle: String {
        title.isEmpty ? "New Chat" : title
    }
}

public enum MessageSearch {
    public static func ftsQuery(_ text: String) -> String? {
        let tokens = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    /// The top-K `matchLimit` lives inside the match CTE: ranking every hit before
    /// narrowing costs 59 ms on a 20k-message corpus instead of 13 ms.
    public static func hits(
        matching text: String,
        limit: Int = 40,
        matchLimit: Int = 300
    ) -> some StructuredQueriesCore.Statement<SearchHit> {
        let query = ftsQuery(text) ?? ""
        // MATERIALIZED is load-bearing: without it SQLite flattens the match into the
        // join, and `snippet()` is only legal where the FTS table is the sole source.
        return #sql(
            """
            WITH "matches" AS MATERIALIZED (
              SELECT
                "threadID" AS "tid",
                snippet("messageSearch", 2, '', '', '…', 12) AS "snippet",
                rank AS "score"
              FROM "messageSearch"
              WHERE "messageSearch" MATCH \(bind: query)
              ORDER BY rank
              LIMIT \(bind: matchLimit)
            )
            SELECT "threadID", "title", "snippet", "updatedAt" FROM (
              SELECT
                t."id" AS "threadID",
                t."title" AS "title",
                m."snippet" AS "snippet",
                t."updatedAt" AS "updatedAt",
                min(m."score") AS "best"
              FROM "matches" m
              JOIN "chatThreads" t ON t."id" = m."tid"
              GROUP BY t."id"
            )
            ORDER BY "best"
            LIMIT \(bind: limit)
            """,
            as: SearchHit.self
        )
    }

    public static func recent(limit: Int = 40) -> some StructuredQueriesCore.Statement<SearchHit> {
        #sql(
            """
            SELECT
              t."id" AS "threadID",
              t."title" AS "title",
              coalesce((
                SELECT substr(m."content", 1, 90) FROM "chatMessages" m
                WHERE m."threadID" = t."id"
                ORDER BY m."createdAt" DESC LIMIT 1
              ), '') AS "snippet",
              t."updatedAt" AS "updatedAt"
            FROM "chatThreads" t
            WHERE EXISTS (SELECT 1 FROM "chatMessages" m WHERE m."threadID" = t."id")
            ORDER BY t."updatedAt" DESC
            LIMIT \(bind: limit)
            """,
            as: SearchHit.self
        )
    }
}
