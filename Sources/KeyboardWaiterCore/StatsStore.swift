import Foundation
import SQLite3

public enum StoredInputCategory {
    case all
    case keyboard
    case pointer
    case pointerTravel

    fileprivate var keyIDLikePattern: String? {
        switch self {
        case .all:
            return nil
        case .keyboard:
            return "kc_%"
        case .pointer:
            return "\(PointerActivity.prefix)%"
        case .pointerTravel:
            return "\(PointerTravel.keyIDPrefix)%"
        }
    }

    /// 位移是距离不是次数，除非专门查它，否则要从总计里排除。
    fileprivate var excludesMetrics: Bool {
        switch self {
        case .pointerTravel:
            return false
        case .all, .keyboard, .pointer:
            return true
        }
    }
}

/// 排除 mt_ 指标行的 SQL 片段。前缀是编译期常量，不需要绑定参数。
private let metricExclusionClause = "key_id NOT LIKE '\(PointerTravel.keyIDPrefix)%'"

public struct KeyCount: Equatable {
    public let keyID: String
    public let count: Int
}

public struct HourCount: Equatable {
    public let bucketStart: Int64
    public let total: Int
}

/// 一个应用在某段时间里的输入量。
public struct AppCount: Equatable {
    public let appID: String
    public let keyboardCount: Int
    public let pointerCount: Int

    public var total: Int { keyboardCount + pointerCount }
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
    /// v1 的快照没有这一列，导入时归到 unknown。
    let appID: String

    init(hourBucket: Int64, keyID: String, count: Int, appID: String) {
        self.hourBucket = hourBucket
        self.keyID = keyID
        self.count = count
        self.appID = appID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hourBucket = try container.decode(Int64.self, forKey: .hourBucket)
        keyID = try container.decode(String.self, forKey: .keyID)
        count = try container.decode(Int.self, forKey: .count)
        appID = try container.decodeIfPresent(String.self, forKey: .appID) ?? AppIdentity.unknownID
    }
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
    public static let snapshotSchemaVersion = 2

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
                    app_id TEXT NOT NULL DEFAULT '\(AppIdentity.unknownID)',
                    count INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (hour_bucket, key_id, app_id)
                );
                """
            )
            try migrateToAppDimensionIfNeeded()
        }
    }

    deinit {
        sqlite3_close(db)
    }

    public func increment(
        keyID: String,
        by amount: Int = 1,
        appID: String = AppIdentity.unknownID,
        at date: Date
    ) {
        guard amount > 0 else { return }
        let bucket = HourlyBucket.bucketStart(for: date)
        let resolvedAppID = appID.isEmpty ? AppIdentity.unknownID : appID

        queue.async { [db] in
            var statement: OpaquePointer?
            let sql = """
            INSERT INTO hourly_counts (hour_bucket, key_id, app_id, count)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(hour_bucket, key_id, app_id)
            DO UPDATE SET count = count + excluded.count;
            """

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                return
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int64(statement, 1, bucket)
            sqlite3_bind_text(statement, 2, keyID, -1, sqliteTransient)
            sqlite3_bind_text(statement, 3, resolvedAppID, -1, sqliteTransient)
            sqlite3_bind_int64(statement, 4, Int64(amount))

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

            if category.excludesMetrics {
                sql += " AND " + metricExclusionClause
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
            if category.excludesMetrics {
                clauses.append(metricExclusionClause)
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

    /// 按应用汇总键盘和指针的次数，多到少排序。位移指标照例排除在外。
    public func appCounts(in range: DateInterval?) -> [AppCount] {
        queue.sync {
            var statement: OpaquePointer?
            var sql = """
            SELECT app_id,
                   SUM(CASE WHEN key_id LIKE 'kc_%' THEN count ELSE 0 END) AS keyboard_count,
                   SUM(CASE WHEN key_id LIKE '\(PointerActivity.prefix)%' THEN count ELSE 0 END) AS pointer_count
            FROM hourly_counts
            WHERE \(metricExclusionClause)
            """

            if range != nil {
                sql += " AND hour_bucket >= ? AND hour_bucket < ?"
            }

            sql += """
             GROUP BY app_id
             HAVING keyboard_count + pointer_count > 0
             ORDER BY keyboard_count + pointer_count DESC, app_id ASC;
            """

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                return []
            }

            defer { sqlite3_finalize(statement) }

            if let range {
                sqlite3_bind_int64(statement, 1, HourlyBucket.bucketStart(for: range.start))
                sqlite3_bind_int64(statement, 2, HourlyBucket.bucketStart(forUnixTime: range.end.timeIntervalSince1970 - 0.001) + HourlyBucket.secondsPerHour)
            }

            var result: [AppCount] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let appPointer = sqlite3_column_text(statement, 0) else { continue }
                result.append(
                    AppCount(
                        appID: String(cString: appPointer),
                        keyboardCount: Int(sqlite3_column_int64(statement, 1)),
                        pointerCount: Int(sqlite3_column_int64(statement, 2))
                    )
                )
            }

            return result
        }
    }

    public func hourlySeries(in range: DateInterval) -> [HourCount] {
        queue.sync {
            var totalsByBucket: [Int64: Int] = [:]
            var statement: OpaquePointer?
            let sql = """
            SELECT hour_bucket, SUM(count) AS total_count
            FROM hourly_counts
            WHERE hour_bucket >= ? AND hour_bucket < ?
              AND \(metricExclusionClause)
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
            SELECT hour_bucket, key_id, count, app_id
            FROM hourly_counts
            ORDER BY hour_bucket ASC, key_id ASC, app_id ASC;
            """

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StatsStoreError.execute(String(cString: sqlite3_errmsg(db)))
            }

            defer { sqlite3_finalize(statement) }

            var records: [StatsSnapshotRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let keyPointer = sqlite3_column_text(statement, 1) else { continue }
                let appID = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? AppIdentity.unknownID
                records.append(
                    StatsSnapshotRecord(
                        hourBucket: sqlite3_column_int64(statement, 0),
                        keyID: String(cString: keyPointer),
                        count: Int(sqlite3_column_int64(statement, 2)),
                        appID: appID
                    )
                )
            }

            return StatsSnapshot(schemaVersion: Self.snapshotSchemaVersion, exportedAt: Date(), records: records)
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

        // v1 的快照没有 app_id，仍然可以导入，全部归到 unknown。
        guard snapshot.schemaVersion <= Self.snapshotSchemaVersion else {
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
        INSERT INTO hourly_counts (hour_bucket, key_id, app_id, count)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(hour_bucket, key_id, app_id)
        DO UPDATE SET count = count + excluded.count;
        """

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StatsStoreError.execute(String(cString: sqlite3_errmsg(db)))
        }

        defer { sqlite3_finalize(statement) }

        for record in records {
            sqlite3_bind_int64(statement, 1, record.hourBucket)
            sqlite3_bind_text(statement, 2, record.keyID, -1, sqliteTransient)
            sqlite3_bind_text(statement, 3, record.appID, -1, sqliteTransient)
            sqlite3_bind_int64(statement, 4, Int64(record.count))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StatsStoreError.execute(String(cString: sqlite3_errmsg(db)))
            }

            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }
    }

    /// 0.11.x 之前的表没有 app_id，主键也只有 (hour_bucket, key_id)。
    /// SQLite 改不了主键，只能重建表；老数据整体归到 unknown 这个应用下。
    private func migrateToAppDimensionIfNeeded() throws {
        guard !tableHasAppIDColumn() else { return }

        try execute(sql: "BEGIN IMMEDIATE TRANSACTION;")

        do {
            try execute(
                sql: """
                CREATE TABLE hourly_counts_migrated (
                    hour_bucket INTEGER NOT NULL,
                    key_id TEXT NOT NULL,
                    app_id TEXT NOT NULL DEFAULT '\(AppIdentity.unknownID)',
                    count INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (hour_bucket, key_id, app_id)
                );
                """
            )
            try execute(
                sql: """
                INSERT INTO hourly_counts_migrated (hour_bucket, key_id, app_id, count)
                SELECT hour_bucket, key_id, '\(AppIdentity.unknownID)', count FROM hourly_counts;
                """
            )
            try execute(sql: "DROP TABLE hourly_counts;")
            try execute(sql: "ALTER TABLE hourly_counts_migrated RENAME TO hourly_counts;")
            try execute(sql: "COMMIT;")
        } catch {
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw error
        }
    }

    private func tableHasAppIDColumn() -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(hourly_counts);", -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let namePointer = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: namePointer) == "app_id" { return true }
        }

        return false
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
