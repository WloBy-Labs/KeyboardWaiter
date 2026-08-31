import XCTest
@testable import KeyboardWaiterPet

/// 断言的是性质（什么行为该解锁什么物种、冬眠怎么判定），不是具体阈值，
/// 所以调规则里的参数不会把这些测试调红。
final class PetEcologyTests: XCTestCase {
    private let ecology = PetEcology()

    private func day(_ index: Int) -> Int64 { Int64(index) * 86_400 }

    private func observation(
        day index: Int,
        keyboard: Int = 3_000,
        pointer: Int = 1_000,
        distinctKeys: Int = 30,
        activeHours: Int = 6,
        hourly: [Int]? = nil,
        apps: [String: Int] = ["com.a": 4_000],
        modifiers: Int = 100,
        deletes: Int = 100,
        travel: Int = 100
    ) -> PetDayObservation {
        var hours = hourly ?? Array(repeating: 0, count: 24)
        if hourly == nil {
            for hour in 9..<15 { hours[hour] = (keyboard + pointer) / 6 }
        }
        return PetDayObservation(
            dayStart: day(index), distinctKeys: distinctKeys, activeHours: activeHours,
            keyboardCount: keyboard, pointerCount: pointer, hourlyCounts: hours,
            appCounts: apps, modifierCount: modifiers, deleteCount: deletes, travelUnits: travel
        )
    }

    // MARK: 解锁

    func testSprinterUnlocksOnBigTypingDay() {
        let days = [observation(day: 1), observation(day: 2, keyboard: 25_000)]
        let found = ecology.newDiscoveries(in: days, alreadyDiscovered: [])
        XCTAssertTrue(found.contains { $0.speciesID == "sprinter" })
        XCTAssertEqual(found.first { $0.speciesID == "sprinter" }?.dayStart, day(2))
    }

    func testNightOwlNeedsConsecutiveLateNights() {
        var lateNight = Array(repeating: 0, count: 24)
        lateNight[1] = 500
        let twoNights = (1...2).map { observation(day: $0, hourly: lateNight) }
        let threeNights = (1...3).map { observation(day: $0, hourly: lateNight) }

        XCTAssertFalse(
            ecology.newDiscoveries(in: twoNights, alreadyDiscovered: []).contains { $0.speciesID == "nightowl" },
            "两天不够，规则要求连续三天"
        )
        XCTAssertTrue(
            ecology.newDiscoveries(in: threeNights, alreadyDiscovered: []).contains { $0.speciesID == "nightowl" }
        )
    }

    func testNightOwlBrokenStreakDoesNotUnlock() {
        var lateNight = Array(repeating: 0, count: 24)
        lateNight[1] = 500
        let days = [
            observation(day: 1, hourly: lateNight),
            observation(day: 2, hourly: lateNight),
            observation(day: 3),                      // 断了一天
            observation(day: 4, hourly: lateNight)
        ]
        XCTAssertFalse(
            ecology.newDiscoveries(in: days, alreadyDiscovered: []).contains { $0.speciesID == "nightowl" }
        )
    }

    func testNomadAndBurrowerAreMutuallyExclusiveInPractice() {
        let nomadDay = observation(day: 1, apps: Dictionary(
            uniqueKeysWithValues: (0..<9).map { ("com.app\($0)", 500) }
        ))
        let burrowerDay = observation(day: 2, keyboard: 5_000, pointer: 1_000, apps: ["com.solo": 5_800, "com.other": 200])

        let nomadFound = ecology.newDiscoveries(in: [nomadDay], alreadyDiscovered: [])
        let burrowerFound = ecology.newDiscoveries(in: [burrowerDay], alreadyDiscovered: [])

        XCTAssertTrue(nomadFound.contains { $0.speciesID == "nomad" })
        XCTAssertFalse(nomadFound.contains { $0.speciesID == "burrower" })
        XCTAssertTrue(burrowerFound.contains { $0.speciesID == "burrower" })
        XCTAssertFalse(burrowerFound.contains { $0.speciesID == "nomad" })
    }

    func testAlreadyDiscoveredSpeciesIsNotReported() {
        let days = [observation(day: 1, keyboard: 25_000)]
        let found = ecology.newDiscoveries(in: days, alreadyDiscovered: ["sprinter"])
        XCTAssertFalse(found.contains { $0.speciesID == "sprinter" })
    }

    // MARK: 栖息地活跃度

    func testVitalityFadesWhenBehaviourStops() {
        let busy = (1...7).map { observation(day: $0, keyboard: 25_000) }
        let quiet = (1...7).map { observation(day: $0, keyboard: 1_000) }

        let hot = ecology.vitality(for: "sprinter", recentObservations: busy)
        let cold = ecology.vitality(for: "sprinter", recentObservations: quiet)

        XCTAssertGreaterThan(hot, 0.9)
        XCTAssertLessThan(cold, 0.25, "不再这么用了，物种应该进入冬眠")
    }

    func testDormantThreshold() {
        let quiet = (1...7).map { observation(day: $0, keyboard: 500) }
        let snapshot = ecology.snapshot(
            discoveries: ["sprinter": day(1)],
            recentObservations: quiet,
            newlyDiscovered: []
        )
        XCTAssertTrue(snapshot.inhabitants[0].isDormant)
    }

    func testSnapshotSortsByVitality() {
        var lateNight = Array(repeating: 0, count: 24)
        lateNight[1] = 500
        let days = (1...7).map { observation(day: $0, keyboard: 25_000, hourly: lateNight) }

        let snapshot = ecology.snapshot(
            discoveries: ["sprinter": day(1), "burrower": day(1)],
            recentObservations: days,
            newlyDiscovered: []
        )

        XCTAssertEqual(snapshot.inhabitants.first?.speciesID, "sprinter")
        XCTAssertEqual(snapshot.discoveredCount, 2)
        XCTAssertEqual(snapshot.undiscoveredCount, PetBestiary.all.count - 2)
    }

    func testEverySpeciesHasNameAndHint() {
        PetStrings.language = .simplifiedChinese
        for species in PetBestiary.all {
            XCTAssertFalse(species.displayName == species.id, "\(species.id) 缺中文名")
            XCTAssertFalse(species.unlockHint.isEmpty, "\(species.id) 缺解锁提示")
        }
        PetStrings.language = .english
        for species in PetBestiary.all {
            XCTAssertFalse(species.displayName == species.id, "\(species.id) 缺英文名")
            XCTAssertFalse(species.unlockHint.isEmpty, "\(species.id) 缺英文提示")
        }
    }
}

/// 0.12.0 之前的历史数据没有应用归因，全记在 unknown 下。
/// 那些日子看起来像「100% 集中在一个应用」，不能拿来解锁深耕种。
final class PetLegacyDataTests: XCTestCase {
    private let ecology = PetEcology()

    private func legacyDay(_ index: Int) -> PetDayObservation {
        PetDayObservation(
            dayStart: Int64(index) * 86_400, distinctKeys: 40, activeHours: 8,
            keyboardCount: 8_000, pointerCount: 2_000,
            hourlyCounts: Array(repeating: 500, count: 24),
            appCounts: ["unknown": 10_000],          // 只有 unknown
            modifierCount: 100, deleteCount: 100, travelUnits: 100
        )
    }

    func testUnknownOnlyDaysDoNotUnlockAppBasedSpecies() {
        let days = (1...10).map { legacyDay($0) }
        let found = ecology.newDiscoveries(in: days, alreadyDiscovered: [])

        XCTAssertFalse(found.contains { $0.speciesID == "burrower" }, "unknown 不是一个真实应用")
        XCTAssertFalse(found.contains { $0.speciesID == "nomad" })
    }

    func testRealAttributionStillUnlocksBurrower() {
        let day = PetDayObservation(
            dayStart: 86_400, distinctKeys: 40, activeHours: 8,
            keyboardCount: 8_000, pointerCount: 2_000,
            hourlyCounts: Array(repeating: 500, count: 24),
            appCounts: ["com.apple.dt.Xcode": 9_000, "com.apple.Safari": 1_000],
            modifierCount: 100, deleteCount: 100, travelUnits: 100
        )
        XCTAssertTrue(
            ecology.newDiscoveries(in: [day], alreadyDiscovered: []).contains { $0.speciesID == "burrower" }
        )
    }
}

/// 连续型物种单日达标但没连上时，界面上不能显示成「已经 100% 了」——那看着像 bug。
final class PetPendingClarityTests: XCTestCase {
    private let ecology = PetEcology()

    func testSingleLateNightIsMarkedAsAwaitingStreak() {
        var lateNight = Array(repeating: 0, count: 24)
        lateNight[1] = 500
        let days = [
            PetDayObservation(dayStart: 86_400, distinctKeys: 30, activeHours: 6,
                              keyboardCount: 3_000, pointerCount: 1_000, hourlyCounts: lateNight,
                              appCounts: ["com.a": 4_000], modifierCount: 100, deleteCount: 100, travelUnits: 100)
        ]

        let pending = ecology.pending(discoveries: [], recentObservations: days)
        let nightOwl = pending.first { $0.speciesID == "nightowl" }

        XCTAssertEqual(nightOwl?.bestStrength, 1.0)
        XCTAssertEqual(nightOwl?.awaitingStreak, true)
    }
}

/// 未发现的物种不能泄露条件，否则解锁那一刻就没有揭晓感了。
final class PetMysteryTests: XCTestCase {
    func testDomainHintOnlyAppearsWhenClose() {
        PetStrings.language = .simplifiedChinese
        defer { PetStrings.language = .english }

        let far = PetStrings.pendingCondition(speciesID: "sprinter", revealsDomain: false)
        let close = PetStrings.pendingCondition(speciesID: "sprinter", revealsDomain: true)

        XCTAssertEqual(far, PetStrings.undiscoveredCondition, "还差得远时不该透露任何方向")
        XCTAssertNotEqual(close, far)
        XCTAssertFalse(
            close.contains("两万"),
            "透露方向不等于透露条件——具体数字不能出现"
        )
    }

    func testDomainRevealThreshold() {
        let ecology = PetEcology()
        let strong = PetDayObservation(
            dayStart: 86_400, distinctKeys: 40, activeHours: 8,
            keyboardCount: 18_000, pointerCount: 2_000,          // 疾行种 90%
            hourlyCounts: Array(repeating: 800, count: 24),
            appCounts: ["com.a": 20_000], modifierCount: 100, deleteCount: 100, travelUnits: 50
        )
        let pending = ecology.pending(discoveries: [], recentObservations: [strong])
        XCTAssertEqual(pending.first { $0.speciesID == "sprinter" }?.revealsDomain, true)
        XCTAssertEqual(pending.first { $0.speciesID == "wanderer" }?.revealsDomain, false)
    }

    func testUndiscoveredStringsRevealNothing() {
        for language in [PetLanguage.english, .simplifiedChinese] {
            PetStrings.language = language

            let name = PetStrings.undiscoveredName
            let condition = PetStrings.undiscoveredCondition

            for species in PetBestiary.all {
                XCTAssertNotEqual(name, PetStrings.speciesName(species.id))
                XCTAssertNotEqual(condition, PetStrings.speciesHint(species.id))
                XCTAssertFalse(
                    condition.contains(PetStrings.speciesName(species.id)),
                    "占位文案不能包含任何物种名"
                )
            }
        }
        PetStrings.language = .english
    }

    func testDiscoveredSpeciesStillExplainsItself() {
        PetStrings.language = .simplifiedChinese
        for species in PetBestiary.all {
            XCTAssertFalse(species.unlockHint.isEmpty, "\(species.id) 发现之后必须能说清为什么")
        }
        PetStrings.language = .english
    }
}
