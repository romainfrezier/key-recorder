import Foundation
import CryptoKit
import SQLite3
import Combine

enum SessionCatalogError: LocalizedError {
    case database(String)
    case archiveMissing
    case sessionMissing

    var errorDescription: String? {
        switch self {
        case .database(let message): return "Session database error: \(message)"
        case .archiveMissing: return "The archived CSV is missing."
        case .sessionMissing: return "The session no longer exists."
        }
    }
}

@MainActor
final class SessionCatalog: ObservableObject {
    @Published private(set) var sessions: [SessionEntry] = []

    let rootURL: URL
    private let csvDirectory: URL
    private var database: OpaquePointer?

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(rootURL: URL? = nil) {
        let defaultRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Key Recorder", isDirectory: true)
        self.rootURL = rootURL ?? defaultRoot
        self.csvDirectory = self.rootURL.appendingPathComponent("CSV", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: self.csvDirectory, withIntermediateDirectories: true)
            let databaseURL = self.rootURL.appendingPathComponent("Sessions.sqlite3")
            guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
                throw SessionCatalogError.database("Unable to open Sessions.sqlite3")
            }
            try migrate()
            refresh()
        } catch {
            database = nil
            sessions = []
        }
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func refresh(search: String = "") {
        guard database != nil else { return }

        do {
            let sql: String
            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sql = """
                SELECT id, title, experiment_id, subject, operator_name, protocol_name, tags, notes,
                       status, created_at, started_at, ended_at, archive_path, key1_name, key2_name,
                       duration, interval, checksum, archive_size
                FROM sessions ORDER BY created_at DESC;
                """
            } else {
                sql = """
                SELECT id, title, experiment_id, subject, operator_name, protocol_name, tags, notes,
                       status, created_at, started_at, ended_at, archive_path, key1_name, key2_name,
                       duration, interval, checksum, archive_size
                FROM sessions
                WHERE title LIKE ? OR experiment_id LIKE ? OR subject LIKE ? OR operator_name LIKE ?
                   OR protocol_name LIKE ? OR tags LIKE ? OR notes LIKE ?
                ORDER BY created_at DESC;
                """
            }

            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let pattern = "%\(search)%"
                for index in 1...7 { bind(pattern, at: index, in: statement) }
            }

            var loaded: [SessionEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                loaded.append(readSession(from: statement))
            }
            sessions = loaded
        } catch {
            sessions = []
        }
    }

    func newSessionID() -> String { UUID().uuidString.lowercased() }

    func archiveURL(for sessionID: String) -> URL {
        csvDirectory.appendingPathComponent("\(sessionID).csv")
    }

    func archiveCSV(from sourceURL: URL, for sessionID: String) throws -> URL {
        let sourceData = try Data(contentsOf: sourceURL)
        let destinationURL = archiveURL(for: sessionID)
        try writeAtomically(sourceData, to: destinationURL)
        if sourceURL.standardizedFileURL != destinationURL.standardizedFileURL {
            try? FileManager.default.removeItem(at: sourceURL)
        }
        return destinationURL
    }

    func importCSV(from sourceURL: URL) throws -> SessionEntry {
        let data = try Data(contentsOf: sourceURL)
        let preview = try CSVDocument.parse(data: data)
        let id = newSessionID()
        let destinationURL = archiveURL(for: id)
        try writeAtomically(data, to: destinationURL)

        let values = try fileValues(for: destinationURL)
        let draft = SessionMetadataDraft(title: sourceURL.deletingPathExtension().lastPathComponent)
        try insert(
            id: id,
            draft: draft,
            status: .imported,
            createdAt: Date(),
            startedAt: nil,
            endedAt: nil,
            archiveURL: destinationURL,
            key1Name: preview.key1Name,
            key2Name: preview.key2Name,
            duration: 0,
            interval: 0,
            checksum: values.checksum,
            archiveSize: values.size
        )
        refresh()
        guard let session = sessions.first(where: { $0.id == id }) else {
            throw SessionCatalogError.sessionMissing
        }
        return session
    }

    func register(
        id: String,
        status: SessionStatus,
        startedAt: Date?,
        endedAt: Date?,
        config: RecordingConfig,
        archiveURL: URL,
        draft: SessionMetadataDraft
    ) throws -> SessionEntry {
        let values = try fileValues(for: archiveURL)
        try insert(
            id: id,
            draft: draft,
            status: status,
            createdAt: Date(),
            startedAt: startedAt,
            endedAt: endedAt,
            archiveURL: archiveURL,
            key1Name: config.key1Name,
            key2Name: config.key2Name,
            duration: config.duration,
            interval: config.interval,
            checksum: values.checksum,
            archiveSize: values.size
        )
        refresh()
        guard let session = sessions.first(where: { $0.id == id }) else {
            throw SessionCatalogError.sessionMissing
        }
        return session
    }

    func updateMetadata(for sessionID: String, draft: SessionMetadataDraft) throws {
        let statement = try prepare("""
            UPDATE sessions
            SET title = ?, experiment_id = ?, subject = ?, operator_name = ?, protocol_name = ?, tags = ?, notes = ?
            WHERE id = ?;
            """)
        defer { sqlite3_finalize(statement) }
        bind(draft.title, at: 1, in: statement)
        bind(draft.experimentID, at: 2, in: statement)
        bind(draft.subject, at: 3, in: statement)
        bind(draft.operatorName, at: 4, in: statement)
        bind(draft.protocolName, at: 5, in: statement)
        bind(draft.tags, at: 6, in: statement)
        bind(draft.notes, at: 7, in: statement)
        bind(sessionID, at: 8, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw databaseError() }
        refresh()
    }

    func preview(for session: SessionEntry) throws -> CSVPreview {
        let url = archiveURL(for: session.id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SessionCatalogError.archiveMissing
        }
        return try CSVDocument.parse(data: Data(contentsOf: url))
    }

    func export(session: SessionEntry, to destinationURL: URL) throws -> URL {
        let sourceURL = archiveURL(for: session.id)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw SessionCatalogError.archiveMissing
        }
        var destination = destinationURL
        if destination.pathExtension.lowercased() != "csv" {
            destination.appendPathExtension("csv")
        }
        try writeAtomically(Data(contentsOf: sourceURL), to: destination)
        return destination
    }

    func removeFromCatalog(_ session: SessionEntry) throws {
        let statement = try prepare("DELETE FROM sessions WHERE id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(session.id, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw databaseError() }
        refresh()
    }

    func deleteArchive(for session: SessionEntry) throws {
        let url = archiveURL(for: session.id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func archiveIsCurrent(_ session: SessionEntry) -> Bool {
        guard let values = try? fileValues(for: archiveURL(for: session.id)) else { return false }
        return values.checksum == session.checksum
    }

    private func migrate() throws {
        try execute("PRAGMA journal_mode = WAL;")
        let version = try scalarInt("PRAGMA user_version;")
        if version < 1 {
            try execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL DEFAULT '',
                    experiment_id TEXT NOT NULL DEFAULT '',
                    subject TEXT NOT NULL DEFAULT '',
                    operator_name TEXT NOT NULL DEFAULT '',
                    protocol_name TEXT NOT NULL DEFAULT '',
                    tags TEXT NOT NULL DEFAULT '',
                    notes TEXT NOT NULL DEFAULT '',
                    status TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    started_at REAL,
                    ended_at REAL,
                    archive_path TEXT NOT NULL UNIQUE,
                    key1_name TEXT NOT NULL,
                    key2_name TEXT NOT NULL,
                    duration REAL NOT NULL,
                    interval REAL NOT NULL,
                    checksum TEXT NOT NULL,
                    archive_size INTEGER NOT NULL
                );
                CREATE INDEX IF NOT EXISTS sessions_created_at ON sessions(created_at DESC);
                CREATE INDEX IF NOT EXISTS sessions_experiment_id ON sessions(experiment_id);
                CREATE INDEX IF NOT EXISTS sessions_subject ON sessions(subject);
                PRAGMA user_version = 1;
                """)
        }
    }

    private func insert(
        id: String,
        draft: SessionMetadataDraft,
        status: SessionStatus,
        createdAt: Date,
        startedAt: Date?,
        endedAt: Date?,
        archiveURL: URL,
        key1Name: String,
        key2Name: String,
        duration: TimeInterval,
        interval: TimeInterval,
        checksum: String,
        archiveSize: Int64
    ) throws {
        let statement = try prepare("""
            INSERT OR REPLACE INTO sessions
            (id, title, experiment_id, subject, operator_name, protocol_name, tags, notes, status,
             created_at, started_at, ended_at, archive_path, key1_name, key2_name, duration, interval,
             checksum, archive_size)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """)
        defer { sqlite3_finalize(statement) }
        bind(id, at: 1, in: statement)
        bind(draft.title, at: 2, in: statement)
        bind(draft.experimentID, at: 3, in: statement)
        bind(draft.subject, at: 4, in: statement)
        bind(draft.operatorName, at: 5, in: statement)
        bind(draft.protocolName, at: 6, in: statement)
        bind(draft.tags, at: 7, in: statement)
        bind(draft.notes, at: 8, in: statement)
        bind(status.rawValue, at: 9, in: statement)
        bind(createdAt.timeIntervalSince1970, at: 10, in: statement)
        bind(startedAt?.timeIntervalSince1970, at: 11, in: statement)
        bind(endedAt?.timeIntervalSince1970, at: 12, in: statement)
        bind(archiveURL.lastPathComponent == "" ? "" : "CSV/\(archiveURL.lastPathComponent)", at: 13, in: statement)
        bind(key1Name, at: 14, in: statement)
        bind(key2Name, at: 15, in: statement)
        bind(duration, at: 16, in: statement)
        bind(interval, at: 17, in: statement)
        bind(checksum, at: 18, in: statement)
        bind(archiveSize, at: 19, in: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw databaseError() }
    }

    private func fileValues(for url: URL) throws -> (checksum: String, size: Int64) {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return (digest, Int64(data.count))
    }

    private func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw databaseError()
        }
        return statement
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw databaseError()
        }
    }

    private func scalarInt(_ sql: String) throws -> Int {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw databaseError() }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func readSession(from statement: OpaquePointer) -> SessionEntry {
        func text(_ index: Int) -> String { String(cString: sqlite3_column_text(statement, Int32(index))) }
        func date(_ index: Int) -> Date? {
            guard sqlite3_column_type(statement, Int32(index)) != SQLITE_NULL else { return nil }
            return Date(timeIntervalSince1970: sqlite3_column_double(statement, Int32(index)))
        }

        return SessionEntry(
            id: text(0), title: text(1), experimentID: text(2), subject: text(3), operatorName: text(4),
            protocolName: text(5), tags: text(6), notes: text(7),
            status: SessionStatus(rawValue: text(8)) ?? .imported,
            createdAt: date(9) ?? Date(), startedAt: date(10), endedAt: date(11), archiveRelativePath: text(12),
            key1Name: text(13), key2Name: text(14), duration: sqlite3_column_double(statement, 15),
            interval: sqlite3_column_double(statement, 16), checksum: text(17), archiveSize: Int64(sqlite3_column_int64(statement, 18))
        )
    }

    private func bind(_ value: String?, at index: Int, in statement: OpaquePointer) {
        guard let value else { sqlite3_bind_null(statement, Int32(index)); return }
        _ = value.withCString { sqlite3_bind_text(statement, Int32(index), $0, -1, Self.transient) }
    }

    private func bind(_ value: Double?, at index: Int, in statement: OpaquePointer) {
        guard let value else { sqlite3_bind_null(statement, Int32(index)); return }
        sqlite3_bind_double(statement, Int32(index), value)
    }

    private func bind(_ value: Int64, at index: Int, in statement: OpaquePointer) {
        sqlite3_bind_int64(statement, Int32(index), value)
    }

    private func databaseError() -> SessionCatalogError {
        SessionCatalogError.database(database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown database error")
    }
}
