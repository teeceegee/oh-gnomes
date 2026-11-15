import Foundation
import SQLite3
import GnomesCore

public enum DatabaseError: Error, CustomStringConvertible {
    case connectionFailed(String)
    case executionFailed(String)
    case prepareFailed(String)
    case stepFailed(String)

    public var description: String {
        switch self {
        case .connectionFailed(let msg): return "SQLite Connection Failed: \(msg)"
        case .executionFailed(let msg): return "SQLite Execution Failed: \(msg)"
        case .prepareFailed(let msg): return "SQLite Prepare Failed: \(msg)"
        case .stepFailed(let msg): return "SQLite Step Failed: \(msg)"
        }
    }
}

public final class SQLiteDatabase: @unchecked Sendable {
    private var dbPointer: OpaquePointer?
    private let lock = NSLock()

    public init(path: String = ":memory:") throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.connectionFailed(errorMsg)
        }
        self.dbPointer = db

        // Enable Write-Ahead Logging (WAL) and foreign keys
        try execute(sql: "PRAGMA journal_mode = WAL;")
        try execute(sql: "PRAGMA foreign_keys = ON;")
        try createTables()
    }

    deinit {
        if let db = dbPointer {
            sqlite3_close_v2(db)
        }
    }

    public func execute(sql: String) throws {
        lock.lock()
        defer { lock.unlock() }

        var errorMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(dbPointer, sql, nil, nil, &errorMsg) != SQLITE_OK {
            let message = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMsg)
            throw DatabaseError.executionFailed(message)
        }
    }

    private func createTables() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS gnomes (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            archetype TEXT NOT NULL,
            portrait_asset TEXT NOT NULL,
            biography TEXT NOT NULL,
            traits_json TEXT NOT NULL,
            speed REAL NOT NULL,
            acceleration REAL NOT NULL,
            stamina REAL NOT NULL,
            balance REAL NOT NULL,
            recovery REAL NOT NULL
        );

        CREATE TABLE IF NOT EXISTS career_records (
            gnome_id TEXT PRIMARY KEY,
            races_run INTEGER NOT NULL DEFAULT 0,
            wins INTEGER NOT NULL DEFAULT 0,
            podiums INTEGER NOT NULL DEFAULT 0,
            incidents_encountered INTEGER NOT NULL DEFAULT 0,
            form_rating REAL NOT NULL DEFAULT 0.0,
            FOREIGN KEY (gnome_id) REFERENCES gnomes (id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS race_events (
            id TEXT PRIMARY KEY,
            race_id TEXT NOT NULL,
            sequence INTEGER NOT NULL,
            tick INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            checksum TEXT NOT NULL,
            idempotency_key TEXT NOT NULL,
            created_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_race_events_race ON race_events (race_id, sequence);

        CREATE TABLE IF NOT EXISTS settlements (
            id TEXT PRIMARY KEY,
            race_id TEXT NOT NULL,
            player_id TEXT NOT NULL,
            bet_id TEXT UNIQUE NOT NULL,
            result TEXT NOT NULL,
            payout_pennies INTEGER NOT NULL,
            balance_before INTEGER NOT NULL,
            balance_after INTEGER NOT NULL,
            settled_at TEXT NOT NULL
        );
        """
        try execute(sql: sql)
    }

    public func getRawPointer() -> OpaquePointer? {
        return dbPointer
    }

    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
