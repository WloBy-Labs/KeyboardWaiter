import Foundation
#if SWIFT_PACKAGE
import KeyboardWaiterCore
#endif

/// 一天的完整画像。物种规则只看这个结构，不碰数据库。
public struct PetDayObservation: Equatable {
    public let dayStart: Int64
    public let distinctKeys: Int
    public let activeHours: Int
    public let keyboardCount: Int
    public let pointerCount: Int
    /// 24 个本地小时各自的输入量
    public let hourlyCounts: [Int]
    /// 应用 → 当天输入量
    public let appCounts: [String: Int]
    /// ⌘⌥⌃⇧ 这些修饰键的按下次数
    public let modifierCount: Int
    /// 删除键次数，反映修改率
    public let deleteCount: Int
    /// 指针行程单位数
    public let travelUnits: Int

    public var total: Int { keyboardCount + pointerCount }

    public init(
        dayStart: Int64,
        distinctKeys: Int,
        activeHours: Int,
        keyboardCount: Int,
        pointerCount: Int,
        hourlyCounts: [Int],
        appCounts: [String: Int],
        modifierCount: Int,
        deleteCount: Int,
        travelUnits: Int
    ) {
        self.dayStart = dayStart
        self.distinctKeys = distinctKeys
        self.activeHours = activeHours
        self.keyboardCount = keyboardCount
        self.pointerCount = pointerCount
        self.hourlyCounts = hourlyCounts
        self.appCounts = appCounts
        self.modifierCount = modifierCount
        self.deleteCount = deleteCount
        self.travelUnits = travelUnits
    }

    /// 某个时段（本地小时，闭开区间）内的输入量
    public func count(inHours range: Range<Int>) -> Int {
        range.compactMap { hour in
            hourlyCounts.indices.contains(hour) ? hourlyCounts[hour] : nil
        }.reduce(0, +)
    }

    /// 当天输入最集中的那个应用占了多少
    public var topAppShare: Double {
        guard total > 0, let top = appCounts.values.max() else { return 0 }
        return Double(top) / Double(total)
    }

    /// 当天有输入的应用个数
    public var activeAppCount: Int {
        appCounts.filter { $0.value > 0 }.count
    }

    /// 这天的数据有没有真实的应用归因。
    /// 0.12.0 之前的历史行全部记在 `unknown` 下，看起来像「一整天只用了一个应用」，
    /// 依赖应用维度的规则必须跳过这种日子，否则会误判成深耕。
    public var hasAppAttribution: Bool {
        appCounts.keys.contains { $0 != "unknown" }
    }
}

/// 观测数据从哪来。宠物模块只认这个协议。
public protocol PetObservationSource: AnyObject {
    /// 返回 [from, to] 之间每一天的画像，升序，没有输入的日子直接不返回。
    func petObservations(from dayStart: Int64, to dayEnd: Int64) -> [PetDayObservation]
}
