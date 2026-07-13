import Foundation
import SQLite3

public enum StoredInputCategory {
    case all
    case keyboard
    case pointer

    fileprivate var keyIDLikePattern: String? {
        switch self {
        case .all:
            return nil
        case .keyboard:
            return "kc_%"
        case .pointer:
            return "\(PointerActivity.prefix)%"
        }
    }
}

public struct KeyCount: Equatable {
    public let keyID: String
    public let count: Int
}

public struct HourCount: Equatable {
    public let bucketStart: Int64
    public let total: Int
}

public struct KeyCountMap: Equatable {
    public let countsByKeyID: [String: Int]
    public let total: Int
}

public enum StatsImportMode {
    case merge
    case replace
}

public struct StatsTransferSummary: Equatable {
    public let recordCount: Int
    public let totalCount: Int
}

private struct StatsSnapshot: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let records: [StatsSnapshotRecord]
}

private struct StatsSnapshotRecord: Codable {
    let hourBucket: Int64
    let keyID: String
    let count: Int
}

enum StatsStoreError: LocalizedError {
    case openDatabase(String)
    case execute(String)
    case invalidSnapshot(String)

    var errorDescription: String? {
        switch self {
        case .openDatabase(let message):
            return "Unable to open the database: \(message)"
        case .execute(let message):
            return "Database operation failed: \(message)"
        case .invalidSnapshot(let message):
            return "Snapshot file is invalid: \(message)"
        }
    }
}

public final class StatsStore {
    public let dataDirectoryURL: URL
    public let databaseURL: URL

    private let queue = DispatchQueue(label: "keyboard_waiter.stats_store")
    private let db: OpaquePointer

    public init(baseDirectoryURL: URL? = nil) throws {
        let appSupportDirectory = baseDirectoryURL ?? Self.defaultDataDirectory()
        if baseDirectoryURL == nil {
            try Self.migrateLegacyDatabaseIfNeeded(into: appSupportDirectory)
        }
        try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)

        dataDirectoryURL = appSupportDirectory
        databaseURL = appSupportDirectory.appendingPathComponent("keyboard_waiter.sqlite3")

        var dbPointer: OpaquePointer?
        let openStatus = sqlite3_open_v2(
            databaseURL.path,
            &dbPointer,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard openStatus == SQLITE_OK, let dbPointer else {
            let message = dbPointer.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let dbPointer {
                sqlite3_close(dbPointer)
            }
            throw StatsStoreError.openDatabase(message)
        }

        db = dbPointer

        try queue.sync {
            try execute(sql: "PRAGMA journal_mode=WAL;")
            try execute(
                sql: """
                CREATE TABLE IF NOT EXISTS hourly_counts (
                    hour_bucket INTEGER NOT NULL,
                    key_id TEXT NOT NULL,
                    count INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (hour_bucket, key_id)
                );
                """
            )
        }
    }

    deinit {
        sqlite3_close(db)
    }

    public func increment(keyID: String, at date: Date) {
        let bucket = HourlyBucket.bucketStart(for: date)

        queue.async { [db] in
            var statement: OpaquePointer?
            let sql = """
            INSERT INTO hourly_counts (hour_bucket, key_id, count)
            VALUES (?, ?, 1)
            ON CONFLICT(hour_bucket, key_id)
            DO UPDATE SET count = count + 1;
            """

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                return
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int64(statement, 1, bucket)
            sqlite3_bind_text(statement, 2, keyID, -1, sqliteTransient)

            _ = sqlite3_step(statement)
        }
    }

    public func todayTotal(now: Date = Date(), category: StoredInputCategory = .all) -> Int {
        let todayRange = HourlyBucket.todayRange(containing: now)
        return totalCount(in: todayRange, category: category)
    }

    public func totalCount(in range: DateInterval, category: StoredInputCategory = .all) -> Int {
        queue.sync {
            var statement: OpaquePointer?
            var sql = """
            SELECT COALESCE(SUM(count), 0)
            FROM hourly_counts
            WHERE hour_bucket >= ? AND hour_bucket < ?
            """

            if category.keyIDLikePattern != nil {
                sql += " AND key_id LIKE ?"
            }

            sql += ";"

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                return 0
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int64(statement, 1, HourlyBucket.bucketStart(for: range.start))
            sqlite3_bind_int64(statement, 2, HourlyBucket.bucketStart(forUnixTime: range.end.timeIntervalSince1970 - 0.001) + HourlyBucket.secondsPerHour)
            if let keyIDLikePattern = category.keyIDLikePattern {
                sqlite3_bind_text(statement, 3, keyIDLikePattern, -1, sqliteTransient)
            }

            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    public func topKeys(in range: DateInterval, limit: Int, category: StoredInputCategory = .all) -> [KeyCount] {
        keyCounts(in: range, category: category)
            .sorted {
                if $0.count == $1.count {
                    return $0.keyID < $1.keyID
                }

                return $0.count > $1.count
            }
            .prefix(limit)
            .map { $0 }
    }

    public func keyCounts(in range: DateInterval?, category: StoredInputCategory = .all) -> [KeyCount] {
        queue.sync {
            var statement: OpaquePointer?
            var sql = """
            SELECT key_id, SUM(count) AS total_count
            FROM hourly_counts
            """

            var clauses: [String] = []
            if range != nil {
                clauses.append("hour_bucket >= ? AND hour_bucket < ?")
            }
            if category.keyIDLikePattern != nil {
                clauses.append("key_id LIKE ?")
            }

            if !clauses.isEmpty {
                sql += " WHERE " + clauses.joined(separator: " AND ")
            }

            sql += """
             GROUP BY key_id
             ORDER BY total_count DESC, key_id ASC;
            """

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                return []
            }

            defer { sqlite3_finalize(statement) }

            var nextParameterIndex: Int32 = 1
            if let range {
                sqlite3_bind_int64(statement, nextParameterIndex, HourlyBucket.bucketStart(for: range.start))
                nextParameterIndex += 1
                sqlite3_bind_int64(statement, nextParameterIndex, HourlyBucket.bucketStart(forUnixTime: range.end.timeIntervalSince1970 - 0.001) + HourlyBucket.secondsPerHour)
                nextParameterIndex += 1
            }

            if let keyIDLikePattern = category.keyIDLikePattern {
                sqlite3_bind_text(statement, nextParameterIndex, keyIDLikePattern, -1, sqliteTransient)
            }

            var result: [KeyCount] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let keyPointer = sqlite3_column_text(statement, 0) else { continue }
                result.append(
                    KeyCount(
                        keyID: String(cString: keyPointer),
                        count: Int(sqlite3_column_int64(statement, 1))
                    )
                )
            }

            return result
        }
    }

    public func keyCountMap(in range: DateInterval?, category: StoredInputCategory = .all) -> KeyCountMap {
        let entries = keyCounts(in: range, category: category)
        let countsByKeyID = Dictionary(uniqueKeysWithValues: entries.map { ($0.keyID, $0.count) })
        let total = entries.reduce(into: 0) { partialResult, entry in
            partialResult += entry.count
        }

        return KeyCountMap(countsByKeyID: countsByKeyID, total: total)
    }

    public func hourlySeries(in range: DateInterval) -> [HourCount] {
        queue.sync {
            var totalsByBucket: [Int64: Int] = [:]
            var statement: OpaquePointer?
            let sql = """
            SELECT hour_bucket, SUM(count) AS total_count
            FROM hourly_counts
            WHERE hour_bucket >= ? AND hour_bucket < ?
            GROUP BY hour_bucket
            ORDER BY hour_bucket ASC;
            """

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                return []
            }

            defer { sqlite3_finalize(statement) }

            let startBucket = HourlyBucket.bucketStart(for: range.start)
            let endBucketExclusive = HourlyBucket.bucketStart(forUnixTime: range.end.timeIntervalSince1970 - 0.001) + HourlyBucket.secondsPerHour

            sqlite3_bind_int64(statement, 1, startBucket)
            sqlite3_bind_int64(statement, 2, endBucketExclusive)

            while sqlite3_step(statement) == SQLITE_ROW {
                let bucket = sqlite3_column_int64(statement, 0)
                let total = Int(sqlite3_column_int64(statement, 1))
                totalsByBucket[bucket] = total
            }

            var series: [HourCount] = []
            var bucket = startBucket

            while bucket < endBucketExclusive {
                series.append(HourCount(bucketStart: bucket, total: totalsByBucket[bucket] ?? 0))
                bucket += HourlyBucket.secondsPerHour
            }

            return series
        }
    }

    public func reset() throws {
        try queue.sync {
            try execute(sql: "DELETE FROM hourly_counts;")
        }
    }

    public func exportSnapshot(to url: URL) throws -> StatsTransferSummary {
        let snapshot = try queue.sync {
            var statement: OpaquePointer?
            let sql = """
            SELECT hour_bucket, key_id, count
            FROM hourly_counts
            ORDER BY hour_bucket ASC, key_id ASC;
            """

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StatsStoreError.execute(String(cString: sqlite3_errmsg(db)))
            }

            defer { sqlite3_finalize(statement) }

            var records: [StatsSnapshotRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let keyPointer = sqlite3_column_text(statement, 1) else { continue }
                records.append(
                    StatsSnapshotRecord(
                        hourBucket: sqlite3_column_int64(statement, 0),
                        keyID: String(cString: keyPointer),
                        count: Int(sqlite3_column_int64(statement, 2))
                    )
                )
            }

            return StatsSnapshot(schemaVersion: 1, exportedAt: Date(), records: records)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)

        return StatsTransferSummary(
            recordCount: snapshot.records.count,
            totalCount: snapshot.records.reduce(0) { $0 + $1.count }
        )
    }

    public func importSnapshot(from url: URL, mode: StatsImportMode) throws -> StatsTransferSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshot: StatsSnapshot
        do {
            snapshot = try decoder.decode(StatsSnapshot.self, from: Data(contentsOf: url))
        } catch {
            throw StatsStoreError.invalidSnapshot(error.localizedDescription)
        }

        guard snapshot.schemaVersion == 1 else {
            throw StatsStoreError.invalidSnapshot("Unsupported schema version \(snapshot.schemaVersion)")
        }

        let records = snapshot.records.filter { $0.count > 0 && !$0.keyID.isEmpty }
        return try queue.sync {
            try execute(sql: "BEGIN IMMEDIATE TRANSACTION;")

            do {
                if mode == .replace {
                    try execute(sql: "DELETE FROM hourly_counts;")
                }

                try importRecords(records)
                try execute(sql: "COMMIT;")
            } catch {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }

            return StatsTransferSummary(
                recordCount: records.count,
                totalCount: records.reduce(0) { $0 + $1.count }
            )
        }
    }

    private func importRecords(_ records: [StatsSnapshotRecord]) throws {
        var statement: OpaquePointer?
        let sql = """
        INSERT INTO hourly_counts (hour_bucket, key_id, count)
        VALUES (?, ?, ?)
        ON CONFLICT(hour_bucket, key_id)
        DO UPDATE SET count = count + excluded.count;
        """

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StatsStoreError.execute(String(cString: sqlite3_errmsg(db)))
        }

        defer { sqlite3_finalize(statement) }

        for record in records {
            sqlite3_bind_int64(statement, 1, record.hourBucket)
            sqlite3_bind_text(statement, 2, record.keyID, -1, sqliteTransient)
            sqlite3_bind_int64(statement, 3, Int64(record.count))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StatsStoreError.execute(String(cString: sqlite3_errmsg(db)))
            }

            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
    }

    private func execute(sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw StatsStoreError.execute(String(cString: sqlite3_errmsg(db)))
        }
    }

    private static func defaultDataDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return applicationSupport.appendingPathComponent("KeyboardWaiter", isDirectory: true)
    }

    private static func legacyDataDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("KeyboardWaiter", isDirectory: true)
    }

    private static func migrateLegacyDatabaseIfNeeded(into destinationDirectory: URL) throws {
        let fileManager = FileManager.default
        let legacyDirectory = legacyDataDirectory()

        guard legacyDirectory.standardizedFileURL != destinationDirectory.standardizedFileURL else {
            return
        }

        let legacyDatabaseURL = legacyDirectory.appendingPathComponent("keyboard_waiter.sqlite3")
        let destinationDatabaseURL = destinationDirectory.appendingPathComponent("keyboard_waiter.sqlite3")

        guard fileManager.fileExists(atPath: legacyDatabaseURL.path) else { return }
        guard !fileManager.fileExists(atPath: destinationDatabaseURL.path) else { return }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        for suffix in ["", "-wal", "-shm"] {
            let resolvedSourceURL = suffix.isEmpty ? legacyDatabaseURL : URL(fileURLWithPath: legacyDatabaseURL.path + suffix)
            let resolvedDestinationURL = suffix.isEmpty ? destinationDatabaseURL : URL(fileURLWithPath: destinationDatabaseURL.path + suffix)

            if fileManager.fileExists(atPath: resolvedSourceURL.path) {
                try fileManager.copyItem(at: resolvedSourceURL, to: resolvedDestinationURL)
            }
        }
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
