import Foundation
import GRDB

/// SQLite-backed history of finished phases, plus the live timer state so a
/// running cycle survives quitting and relaunching the app.
///
/// Both live in one database so they're saved in a single transaction: a
/// crash can never record a phase without also advancing the timer past it
/// (which would record it twice on the next launch), or the other way round.
public struct HistoryStore: Sendable {
    private let writer: any DatabaseWriter

    /// Opens (creating if needed) the database at `url` and migrates it.
    public static func open(at url: URL) throws -> HistoryStore {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try HistoryStore(writer: DatabasePool(path: url.path))
    }

    /// A throwaway database for tests and previews.
    public static func inMemory() throws -> HistoryStore {
        try HistoryStore(writer: DatabaseQueue())
    }

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    // MARK: - Writing

    public func insert(_ records: [SessionRecord]) throws {
        guard !records.isEmpty else { return }
        try writer.write { db in
            for record in records { try record.insert(db) }
        }
    }

    /// Saves the timer state and any newly finished records atomically.
    public func save(state: TimerState, adding records: [SessionRecord] = []) throws {
        let row = AppStateRow(key: AppStateRow.timerKey, value: try JSONEncoder().encode(state))
        try writer.write { db in
            for record in records { try record.insert(db) }
            try row.save(db)
        }
    }

    // MARK: - Reading

    /// The timer state saved by `save(state:adding:)`, or nil if none was saved.
    public func loadTimerState() throws -> TimerState? {
        let row = try writer.read { db in try AppStateRow.fetchOne(db, key: AppStateRow.timerKey) }
        return try row.map { try JSONDecoder().decode(TimerState.self, from: $0.value) }
    }

    /// Sessions overlapping `interval` (including ones straddling its edges), oldest first.
    public func records(in interval: DateInterval) throws -> [SessionRecord] {
        try writer.read { db in
            try SessionRecord
                .filter(Column("startedAt") < interval.end && Column("endedAt") > interval.start)
                .order(Column("startedAt"))
                .fetchAll(db)
        }
    }

    public func totals(in interval: DateInterval) throws -> Totals {
        Totals(try records(in: interval), in: interval)
    }

    // MARK: - Schema

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: SessionRecord.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("phase", .text).notNull()
                t.column("startedAt", .datetime).notNull().indexed()
                t.column("endedAt", .datetime).notNull().indexed()
                t.column("plannedSeconds", .integer).notNull()
                t.column("activeSeconds", .integer).notNull()
                t.column("outcome", .text).notNull()
                t.column("presetName", .text).notNull()
                t.column("tag", .text)
            }
            try db.create(table: AppStateRow.databaseTableName) { t in
                t.primaryKey("key", .text)
                t.column("value", .blob).notNull()
            }
        }
        return migrator
    }
}

extension SessionRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "session"
    // Readable ids when poking at the database with `sqlite3` (GRDB's default is a 16-byte blob).
    public static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy {
        .uppercaseString
    }
}

/// Small key/value table for app state that isn't history.
private struct AppStateRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "appState"
    static let timerKey = "timer"

    var key: String
    var value: Data
}
