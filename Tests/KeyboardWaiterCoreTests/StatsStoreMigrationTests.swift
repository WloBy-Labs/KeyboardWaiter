import SQLite3
import XCTest
@testable import KeyboardWaiterCore

/// 0.12 之前的库没有 app_id，主键是 (hour_bucket, key_id)。这里造一个老库再打开，验证迁移。
final class StatsStoreMigrationTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kw-migrate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func writeLegacyDatabase(rows: [(Int64, String, Int)]) throws {
        let path = directory.appendingPathComponent("keyboard_waiter.sqlite3").path
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let create = """
        CREATE TABLE hourly_counts (
            hour_bucket INTEGER NOT NULL,
            key_id TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (hour_bucket, key_id)
        );
        """
        XCTAssertEqual(sqlite3_exec(db, create, nil, nil, nil), SQLITE_OK)

        for (bucket, keyID, count) in rows {
            let sql = "INSERT INTO hourly_counts (hour_bucket, key_id, count) VALUES (\(bucket), '\(keyID)', \(count));"
            XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)
        }
    }

    func testLegacyRowsSurviveMigrationAsUnknownApp() throws {
        let now = Date()
        let bucket = HourlyBucket.bucketStart(for: now)
        try writeLegacyDatabase(rows: [
            (bucket, "kc_a", 120),
            (bucket, "pd_left_click", 45),
            (bucket - 3600, "kc_b", 7)
        ])

        let store = try StatsStore(baseDirectoryURL: directory)

        XCTAssertEqual(store.todayTotal(now: now, category: .keyboard), 127)
        XCTAssertEqual(store.todayTotal(now: now, category: .pointer), 45)

        let counts = store.appCounts(in: nil)
        XCTAssertEqual(counts.count, 1)
        XCTAssertEqual(counts[0].appID, AppIdentity.unknownID)
        XCTAssertEqual(counts[0].keyboardCount, 127)
        XCTAssertEqual(counts[0].pointerCount, 45)
    }

    func testMigratedStoreAcceptsNewAppScopedWrites() throws {
        let now = Date()
        let bucket = HourlyBucket.bucketStart(for: now)
        try writeLegacyDatabase(rows: [(bucket, "kc_a", 10)])

        let store = try StatsStore(baseDirectoryURL: directory)
        store.increment(keyID: "kc_a", by: 4, appID: "com.apple.dt.Xcode", at: now)
        _ = store.todayTotal(now: now, category: .all)

        // 同一个 (bucket, key) 在两个 app 下并存，键维度合计仍然正确
        let map = store.keyCountMap(in: HourlyBucket.todayRange(containing: now), category: .keyboard)
        XCTAssertEqual(map.countsByKeyID["kc_a"], 14)

        let counts = store.appCounts(in: nil)
        XCTAssertEqual(counts.count, 2)
        XCTAssertEqual(counts.first { $0.appID == AppIdentity.unknownID }?.keyboardCount, 10)
        XCTAssertEqual(counts.first { $0.appID == "com.apple.dt.Xcode" }?.keyboardCount, 4)
    }

    func testMigrationIsIdempotent() throws {
        let bucket = HourlyBucket.bucketStart(for: Date())
        try writeLegacyDatabase(rows: [(bucket, "kc_a", 3)])

        _ = try StatsStore(baseDirectoryURL: directory)
        let reopened = try StatsStore(baseDirectoryURL: directory)

        XCTAssertEqual(reopened.appCounts(in: nil).first?.keyboardCount, 3)
    }

    func testLegacyV1SnapshotStillImports() throws {
        let store = try StatsStore(baseDirectoryURL: directory)
        let bucket = HourlyBucket.bucketStart(for: Date())
        let legacyJSON = """
        {"schemaVersion":1,"exportedAt":"2026-08-30T00:00:00Z",
         "records":[{"hourBucket":\(bucket),"keyID":"kc_z","count":9}]}
        """
        let url = directory.appendingPathComponent("legacy.json")
        try legacyJSON.write(to: url, atomically: true, encoding: .utf8)

        let summary = try store.importSnapshot(from: url, mode: .merge)
        XCTAssertEqual(summary.recordCount, 1)
        XCTAssertEqual(store.appCounts(in: nil).first?.appID, AppIdentity.unknownID)
    }
}
