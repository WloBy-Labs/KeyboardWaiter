import Foundation
#if SWIFT_PACKAGE
import KeyboardWaiterCore
#endif

/// 把宿主的统计库适配成物种规则要的每日画像。
/// 这是宠物模块里唯一碰 `StatsStore` 的地方——换数据源只用换这一个类。
public final class StatsStoreObservationSource: PetObservationSource {
    /// kc_<keycode>：⌘⇧⌥⌃ 和 fn
    private static let modifierKeyIDs: Set<String> = [
        "kc_54", "kc_55",   // command
        "kc_56", "kc_60",   // shift
        "kc_58", "kc_61",   // option
        "kc_59", "kc_62",   // control
        "kc_63"             // fn
    ]
    /// 退格 + 前向删除
    private static let deleteKeyIDs: Set<String> = ["kc_51", "kc_117"]

    private let statsStore: StatsStore
    private let calendar: Calendar
    /// 过去的日子不会再变，算一次就缓存住；只有今天需要反复重算。
    private var cache: [Int64: PetDayObservation] = [:]

    public init(statsStore: StatsStore, calendar: Calendar = .current) {
        self.statsStore = statsStore
        self.calendar = calendar
    }

    public func petObservations(from dayStart: Int64, to dayEnd: Int64) -> [PetDayObservation] {
        guard dayStart <= dayEnd else { return [] }

        let today = Self.startOfDay(Date(), calendar: calendar)
        var result: [PetDayObservation] = []
        var cursor = dayStart

        while cursor <= dayEnd {
            if cursor < today, let cached = cache[cursor] {
                result.append(cached)
            } else if let observation = observation(forDayStart: cursor) {
                if cursor < today { cache[cursor] = observation }
                result.append(observation)
            }
            cursor += 86_400
        }

        return result
    }

    private func observation(forDayStart dayStart: Int64) -> PetDayObservation? {
        let start = Date(timeIntervalSince1970: TimeInterval(dayStart))
        let end = start.addingTimeInterval(86_400)
        let interval = DateInterval(start: start, end: end)

        let keyboardMap = statsStore.keyCountMap(in: interval, category: .keyboard)
        let pointerMap = statsStore.keyCountMap(in: interval, category: .pointer)
        guard keyboardMap.total + pointerMap.total > 0 else { return nil }

        let hourly = statsStore.hourlySeries(in: interval).map(\.total)
        let apps = statsStore.appCounts(in: interval)
        let travel = statsStore.keyCountMap(in: interval, category: .pointerTravel).total

        let modifiers = keyboardMap.countsByKeyID
            .filter { Self.modifierKeyIDs.contains($0.key) }
            .values.reduce(0, +)
        let deletes = keyboardMap.countsByKeyID
            .filter { Self.deleteKeyIDs.contains($0.key) }
            .values.reduce(0, +)

        return PetDayObservation(
            dayStart: dayStart,
            distinctKeys: keyboardMap.countsByKeyID.count,
            activeHours: hourly.filter { $0 > 0 }.count,
            keyboardCount: keyboardMap.total,
            pointerCount: pointerMap.total,
            hourlyCounts: hourly,
            appCounts: Dictionary(uniqueKeysWithValues: apps.map { ($0.appID, $0.total) }),
            modifierCount: modifiers,
            deleteCount: deletes,
            travelUnits: travel
        )
    }

    static func startOfDay(_ date: Date, calendar: Calendar) -> Int64 {
        Int64(calendar.startOfDay(for: date).timeIntervalSince1970)
    }
}
