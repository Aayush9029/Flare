import Dependencies
import Foundation
import SQLiteData
import Testing

@testable import FlareKit

@Suite(
    "Search benchmarks",
    .enabled(if: ProcessInfo.processInfo.environment["FLARE_BENCH"] != nil),
    .serialized
)
struct SearchBenchmarks {
    private static let threadCount = 1_000
    private static let messagesPerThread = 20
    private static let wordsPerMessage = 60
    private static let timestamp = "2026-01-01 00:00:00.000"

    private static let probes = [
        ("very common", "the"),
        ("common", "w20"),
        ("mid", "w300"),
        ("rare", "w4000"),
        ("two terms", "w40 w900"),
        ("no match", "zzzznotpresent"),
    ]

    private struct Corpus {
        let words: [String]
        let cumulative: [Double]

        init(size: Int) {
            words = ["the", "and", "code"] + (0..<size).map { "w\($0)" }
            var running = 0.0
            var sums: [Double] = []
            for index in words.indices {
                running += 1.0 / Double(index + 1)
                sums.append(running)
            }
            cumulative = sums.map { $0 / running }
        }

        func word(_ roll: Double) -> String {
            var low = 0
            var high = cumulative.count - 1
            while low < high {
                let mid = (low + high) / 2
                if cumulative[mid] < roll { low = mid + 1 } else { high = mid }
            }
            return words[low]
        }
    }

    private func seed(_ db: Database, mode: IndexMode) throws {
        let corpus = Corpus(size: 5_000)
        var generator = SystemRandomNumberGenerator()
        for threadIndex in 0..<Self.threadCount {
            let threadID = UUID().uuidString
            try db.execute(
                sql: #"INSERT INTO "chatThreads" VALUES (?, ?, ?, ?, ?)"#,
                arguments: [threadID, "Thread \(threadIndex)", Self.timestamp, Self.timestamp, "gpt-5.6-terra"]
            )
            for messageIndex in 0..<Self.messagesPerThread {
                let content = (0..<Self.wordsPerMessage)
                    .map { _ in corpus.word(Double.random(in: 0..<1, using: &generator)) }
                    .joined(separator: " ")
                let messageID = UUID().uuidString
                try db.execute(
                    sql: #"INSERT INTO "chatMessages" VALUES (?, ?, ?, ?, ?, ?)"#,
                    arguments: [messageID, threadID, "user", content, "", Self.timestamp]
                )
                if mode == .standalone {
                    try db.execute(
                        sql: #"INSERT INTO "messageSearch" ("messageID", "threadID", "content") VALUES (?, ?, ?)"#,
                        arguments: [messageID, threadID, content]
                    )
                }
            }
        }
    }

    private enum IndexMode { case standalone, external }

    private func baseSchema(_ db: Database) throws {
        try db.execute(
            sql: """
            CREATE TABLE "chatThreads" (
              "id" TEXT PRIMARY KEY NOT NULL, "title" TEXT NOT NULL,
              "createdAt" TEXT NOT NULL, "updatedAt" TEXT NOT NULL, "model" TEXT NOT NULL
            ) STRICT
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE "chatMessages" (
              "id" TEXT PRIMARY KEY NOT NULL, "threadID" TEXT NOT NULL,
              "role" TEXT NOT NULL, "content" TEXT NOT NULL,
              "reasoning" TEXT NOT NULL, "createdAt" TEXT NOT NULL
            ) STRICT
            """
        )
        try db.execute(sql: #"CREATE INDEX "m_thread" ON "chatMessages"("threadID", "createdAt")"#)
    }

    @discardableResult
    private func measure(_ label: String, _ body: () throws -> Int) rethrows -> Double {
        for _ in 0..<3 { _ = try body() }
        var samples: [Double] = []
        var rows = 0
        for _ in 0..<15 {
            let start = DispatchTime.now().uptimeNanoseconds
            rows = try body()
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
        samples.sort()
        let median = samples[samples.count / 2]
        print(String(format: "  %-14@ median %8.3f ms   p90 %8.3f ms   rows %d",
                     label as NSString, median, samples[Int(Double(samples.count) * 0.9)], rows))
        return median
    }

    private func report(_ db: Database, _ title: String) throws {
        let pages = try Int.fetchOne(db, sql: "PRAGMA page_count") ?? 0
        let size = try Int.fetchOne(db, sql: "PRAGMA page_size") ?? 0
        print(String(format: "  %@ size %.1f MB", title as NSString, Double(pages * size) / 1_048_576))
    }

    private static let rankAllSQL = """
    WITH "matches" AS MATERIALIZED (
      SELECT "threadID" AS "tid",
             snippet("messageSearch", 2, '', '', '…', 12) AS "snippet",
             rank AS "score"
      FROM "messageSearch" WHERE "messageSearch" MATCH ?
    )
    SELECT count(*) FROM (
      SELECT t."id", t."title", m."snippet", t."updatedAt", min(m."score") AS "best"
      FROM "matches" m JOIN "chatThreads" t ON t."id" = m."tid"
      GROUP BY t."id"
    )
    """

    private static let topKSQL = """
    WITH "matches" AS MATERIALIZED (
      SELECT "threadID" AS "tid",
             snippet("messageSearch", 2, '', '', '…', 12) AS "snippet",
             rank AS "score"
      FROM "messageSearch" WHERE "messageSearch" MATCH ?
      ORDER BY rank LIMIT 300
    )
    SELECT count(*) FROM (
      SELECT t."id", t."title", m."snippet", t."updatedAt", min(m."score") AS "best"
      FROM "matches" m JOIN "chatThreads" t ON t."id" = m."tid"
      GROUP BY t."id" ORDER BY "best" LIMIT 40
    )
    """

    @Test("A. FTS5 standalone, rank every match")
    func rankAll() throws {
        let queue = try standaloneDatabase()
        print("\nA. FTS5 standalone — rank every match")
        try queue.read { db in
            for (label, query) in Self.probes {
                try measure(label) {
                    try Int.fetchOne(db, sql: Self.rankAllSQL, arguments: [MessageSearch.ftsQuery(query) ?? ""]) ?? 0
                }
            }
            try report(db, "standalone")
        }
    }

    @Test("B. FTS5 standalone, top-K inside the match")
    func topK() throws {
        let queue = try standaloneDatabase()
        print("\nB. FTS5 standalone — top-K inside the match")
        try queue.read { db in
            for (label, query) in Self.probes {
                try measure(label) {
                    try Int.fetchOne(db, sql: Self.topKSQL, arguments: [MessageSearch.ftsQuery(query) ?? ""]) ?? 0
                }
            }
        }
    }

    @Test("C. LIKE substring scan")
    func likeScan() throws {
        let queue = try standaloneDatabase()
        print("\nC. LIKE '%term%' scan")
        try queue.read { db in
            for (label, query) in Self.probes {
                try measure(label) {
                    try Int.fetchOne(
                        db,
                        sql: """
                        SELECT count(*) FROM (
                          SELECT t."id" FROM "chatMessages" m
                          JOIN "chatThreads" t ON t."id" = m."threadID"
                          WHERE m."content" LIKE ? GROUP BY t."id" LIMIT 40
                        )
                        """,
                        arguments: ["%\(query)%"]
                    ) ?? 0
                }
            }
        }
    }

    @Test("D. FTS5 trigram, top-K")
    func trigram() throws {
        let queue = try DatabaseQueue()
        try queue.write { db in
            try baseSchema(db)
            try db.execute(
                sql: #"CREATE VIRTUAL TABLE "messageSearch" USING fts5("messageID" UNINDEXED, "threadID" UNINDEXED, "content", tokenize = 'trigram')"#
            )
            try seed(db, mode: .standalone)
        }
        print("\nD. FTS5 trigram — top-K")
        try queue.read { db in
            for (label, query) in Self.probes where query.count >= 3 {
                try measure(label) {
                    try Int.fetchOne(db, sql: Self.topKSQL, arguments: ["\"\(query)\""]) ?? 0
                }
            }
            try report(db, "trigram")
        }
    }

    @Test("E. FTS5 external content, top-K")
    func externalContent() throws {
        let queue = try DatabaseQueue()
        try queue.write { db in
            try baseSchema(db)
            try db.execute(
                sql: """
                CREATE VIRTUAL TABLE "messageSearch" USING fts5(
                  "content", content='chatMessages', content_rowid='rowid',
                  tokenize = 'unicode61 remove_diacritics 2')
                """
            )
            try seed(db, mode: .external)
            try db.execute(sql: #"INSERT INTO "messageSearch"("messageSearch") VALUES('rebuild')"#)
        }
        print("\nE. FTS5 external content — top-K")
        try queue.read { db in
            for (label, query) in Self.probes {
                try measure(label) {
                    try Int.fetchOne(
                        db,
                        sql: """
                        WITH "matches" AS MATERIALIZED (
                          SELECT "rowid" AS "rid",
                                 snippet("messageSearch", 0, '', '', '…', 12) AS "snippet",
                                 rank AS "score"
                          FROM "messageSearch" WHERE "messageSearch" MATCH ?
                          ORDER BY rank LIMIT 300
                        )
                        SELECT count(*) FROM (
                          SELECT t."id", t."title", m."snippet", t."updatedAt", min(m."score") AS "best"
                          FROM "matches" m
                          JOIN "chatMessages" cm ON cm."rowid" = m."rid"
                          JOIN "chatThreads" t ON t."id" = cm."threadID"
                          GROUP BY t."id" ORDER BY "best" LIMIT 40
                        )
                        """,
                        arguments: [MessageSearch.ftsQuery(query) ?? ""]
                    ) ?? 0
                }
            }
            try report(db, "external")
        }
    }

    @Test("F. Shipped MessageSearch.hits")
    func shipped() throws {
        let queue = try standaloneDatabase()
        print("\nF. Shipped MessageSearch.hits")
        try queue.read { db in
            for (label, query) in Self.probes {
                try measure(label) {
                    try MessageSearch.hits(matching: query).fetchAll(db).count
                }
            }
        }
    }

    private func standaloneDatabase() throws -> DatabaseQueue {
        let queue = try DatabaseQueue()
        try queue.write { db in
            try baseSchema(db)
            try db.execute(
                sql: """
                CREATE VIRTUAL TABLE "messageSearch" USING fts5(
                  "messageID" UNINDEXED, "threadID" UNINDEXED, "content",
                  tokenize = 'unicode61 remove_diacritics 2')
                """
            )
            try seed(db, mode: .standalone)
        }
        return queue
    }
}
