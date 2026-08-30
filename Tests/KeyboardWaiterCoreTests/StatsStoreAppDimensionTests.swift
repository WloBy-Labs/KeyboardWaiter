import XCTest
@testable import KeyboardWaiterCore

final class StatsStoreAppDimensionTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kw-app-dim-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func drain(_ store: StatsStore, now: Date) {
        // keyCounts 走 queue.sync，能保证前面所有 async 写入都已落库
        _ = store.todayTotal(now: now, category: .all)
    }

    func testCountsAreSplitByApp() throws {
        let store = try StatsStore(baseDirectoryURL: directory)
        let now = Date()

        store.increment(keyID: "kc_a", by: 30, appID: "com.apple.dt.Xcode", at: now)
        store.increment(keyID: "pd_left_click", by: 10, appID: "com.apple.dt.Xcode", at: now)
        store.increment(keyID: "kc_a", by: 5, appID: "com.apple.Safari", at: now)
        drain(store, now: now)

        let counts = store.appCounts(in: HourlyBucket.todayRange(containing: now))
        XCTAssertEqual(counts.count, 2)
        XCTAssertEqual(counts[0].appID, "com.apple.dt.Xcode")
        XCTAssertEqual(counts[0].keyboardCount, 30)
        XCTAssertEqual(counts[0].pointerCount, 10)
        XCTAssertEqual(counts[0].total, 40)
        XCTAssertEqual(counts[1].appID, "com.apple.Safari")
        XCTAssertEqual(counts[1].total, 5)
    }

    func testAppDimensionDoesNotChangeExistingTotals() throws {
        let store = try StatsStore(baseDirectoryURL: directory)
        let now = Date()

        store.increment(keyID: "kc_a", by: 3, appID: "com.a", at: now)
        store.increment(keyID: "kc_a", by: 4, appID: "com.b", at: now)
        drain(store, now: now)

        // 同一个键分散在两个 App 下，按键维度的查询必须把它们合起来
        let map = store.keyCountMap(in: HourlyBucket.todayRange(containing: now), category: .keyboard)
        XCTAssertEqual(map.countsByKeyID["kc_a"], 7)
        XCTAssertEqual(map.total, 7)
        XCTAssertEqual(store.todayTotal(now: now, category: .keyboard), 7)
    }

    func testTravelMetricStaysOutOfAppCounts() throws {
        let store = try StatsStore(baseDirectoryURL: directory)
        let now = Date()

        store.increment(keyID: "kc_a", by: 2, appID: "com.a", at: now)
        store.increment(keyID: PointerTravel.keyID, by: 500, appID: "com.a", at: now)
        drain(store, now: now)

        let counts = store.appCounts(in: HourlyBucket.todayRange(containing: now))
        XCTAssertEqual(counts.count, 1)
        XCTAssertEqual(counts[0].total, 2, "位移是距离不是次数，不能混进应用排行")
    }

    func testEmptyAppIDFallsBackToUnknown() throws {
        let store = try StatsStore(baseDirectoryURL: directory)
        let now = Date()

        store.increment(keyID: "kc_a", by: 1, appID: "", at: now)
        drain(store, now: now)

        let counts = store.appCounts(in: HourlyBucket.todayRange(containing: now))
        XCTAssertEqual(counts.first?.appID, AppIdentity.unknownID)
    }

    func testSnapshotRoundTripKeepsAppDimension() throws {
        let store = try StatsStore(baseDirectoryURL: directory)
        let now = Date()
        store.increment(keyID: "kc_a", by: 6, appID: "com.apple.dt.Xcode", at: now)
        drain(store, now: now)

        let snapshotURL = directory.appendingPathComponent("snapshot.json")
        _ = try store.exportSnapshot(to: snapshotURL)

        let restoreDirectory = directory.appendingPathComponent("restored")
        let restored = try StatsStore(baseDirectoryURL: restoreDirectory)
        _ = try restored.importSnapshot(from: snapshotURL, mode: .replace)

        let counts = restored.appCounts(in: HourlyBucket.todayRange(containing: now))
        XCTAssertEqual(counts.first?.appID, "com.apple.dt.Xcode")
        XCTAssertEqual(counts.first?.keyboardCount, 6)
    }
}

final class AppIdentityTests: XCTestCase {
    func testFallbackSkipsGenericLastSegment() {
        // 这些 App 不在测试机上，一定走 bundle id 兜底
        XCTAssertEqual(AppIdentity.displayName(for: "com.figma.Desktop"), "Figma")
        XCTAssertEqual(AppIdentity.displayName(for: "com.spotify.client"), "Spotify")
    }

    func testFallbackKeepsMeaningfulLastSegment() {
        XCTAssertEqual(AppIdentity.displayName(for: "com.example.Obsidian"), "Obsidian")
    }

    func testUnknownGetsLocalizedName() {
        XCTAssertEqual(AppIdentity.displayName(for: AppIdentity.unknownID), AppLocalizer.unknownAppName)
    }
}
