import Foundation

/// 物种规则：给一天的画像，返回 0…1 的「强度」。
///
/// 同一个规则同时驱动两件事——强度达到 1.0 就**解锁**这个物种（图鉴），
/// 最近几天的平均强度就是它在**栖息地**里的活跃度。加新物种 = 加一个规则实例，
/// 不用改任何调度逻辑。
public protocol PetSpeciesRule {
    func strength(for observation: PetDayObservation) -> Double
    /// 有些物种要看连续几天，单日算不出来。默认只看当天。
    var windowDays: Int { get }
    /// 跨天规则用这个；单日规则不用实现。
    func strength(forWindow observations: [PetDayObservation]) -> Double
}

public extension PetSpeciesRule {
    var windowDays: Int { 1 }

    func strength(forWindow observations: [PetDayObservation]) -> Double {
        observations.map { strength(for: $0) }.max() ?? 0
    }

    /// 「连续 N 天」类规则的通用判定。
    ///
    /// 两个坑都在这里堵住：窗口不足 N 天必须算 0（不能「有几天算几天」），
    /// 而且这 N 天必须是**真正连续的自然日**——没有输入的日子根本不会出现在观测里，
    /// 只看数组位置会把隔了一天的记录当成连着的。
    func consecutiveStrength(
        _ observations: [PetDayObservation],
        days: Int,
        each: (PetDayObservation) -> Double
    ) -> Double {
        guard observations.count >= days else { return 0 }

        let window = Array(observations.suffix(days))
        for index in 1..<window.count where window[index].dayStart - window[index - 1].dayStart != 86_400 {
            return 0
        }

        return window.map(each).min() ?? 0
    }
}

/// 物种属于哪个方面。条件本身是藏着的，只有在很接近的时候才透露这个方向——
/// 保留悬念，同时给一点着力点。
public enum PetSpeciesDomain: String {
    case rhythm    // 作息、时间
    case keyboard  // 敲键盘的方式
    case pointer   // 鼠标/触控板
    case apps      // 在哪些应用里
}

public struct PetSpecies: Identifiable {
    /// 稳定标识，同时是 sprite 的文件名
    public let id: String
    public let rule: PetSpeciesRule
    public let domain: PetSpeciesDomain

    public var displayName: String { PetStrings.speciesName(id) }
    public var unlockHint: String { PetStrings.speciesHint(id) }
    public var domainHint: String { PetStrings.domainHint(domain) }

    public init(id: String, rule: PetSpeciesRule, domain: PetSpeciesDomain) {
        self.id = id
        self.rule = rule
        self.domain = domain
    }
}

// MARK: - 规则实现
//
// 每个规则都刻意只依赖已有数据，不需要新增采集。
// 阈值都写成参数，调参不用改逻辑。

/// 深夜时段有活动，连续若干天
public struct NightOwlRule: PetSpeciesRule {
    public var hours: Range<Int> = 0..<5
    public var minimumCount = 200
    public var consecutiveDays = 3

    public var windowDays: Int { consecutiveDays }

    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        min(1.0, Double(observation.count(inHours: hours)) / Double(minimumCount))
    }

    public func strength(forWindow observations: [PetDayObservation]) -> Double {
        consecutiveStrength(observations, days: consecutiveDays) { strength(for: $0) }
    }
}

/// 清晨时段有活动
public struct EarlyBirdRule: PetSpeciesRule {
    public var hours: Range<Int> = 5..<9
    public var minimumCount = 200
    public var consecutiveDays = 3

    public var windowDays: Int { consecutiveDays }

    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        min(1.0, Double(observation.count(inHours: hours)) / Double(minimumCount))
    }

    public func strength(forWindow observations: [PetDayObservation]) -> Double {
        consecutiveStrength(observations, days: consecutiveDays) { strength(for: $0) }
    }
}

/// 单日按键量爆发
public struct SprinterRule: PetSpeciesRule {
    public var target = 20_000
    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        min(1.0, Double(observation.keyboardCount) / Double(target))
    }
}

/// 快捷键使用比例高
public struct ShortcutRule: PetSpeciesRule {
    public var targetShare = 0.15
    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        guard observation.keyboardCount > 500 else { return 0 }
        let share = Double(observation.modifierCount) / Double(observation.keyboardCount)
        return min(1.0, share / targetShare)
    }
}

/// 指针行程远
public struct WandererRule: PetSpeciesRule {
    /// 单位数，500 点一个单位，约 11.5 厘米。
    /// 1000 单位 ≈ 115 米：实测重度使用一天约 60 米，所以这是个「今天鼠标特别忙」的门槛。
    public var targetUnits = 1_000
    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        min(1.0, Double(observation.travelUnits) / Double(targetUnits))
    }
}

/// 在很多应用之间来回切
public struct NomadRule: PetSpeciesRule {
    public var targetApps = 8
    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        guard observation.hasAppAttribution else { return 0 }
        return min(1.0, Double(observation.activeAppCount) / Double(targetApps))
    }
}

/// 一整天几乎只待在一个应用里
public struct BurrowerRule: PetSpeciesRule {
    public var targetShare = 0.7
    public var minimumTotal = 2_000
    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        // 没有应用归因的日子（0.12.0 之前）看起来像「100% 集中在一个应用」，那是假象
        guard observation.hasAppAttribution, observation.total >= minimumTotal else { return 0 }
        return min(1.0, observation.topAppShare / targetShare)
    }
}

/// 删除键占比高：改了又改
public struct ReviserRule: PetSpeciesRule {
    public var targetShare = 0.12
    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        guard observation.keyboardCount > 500 else { return 0 }
        let share = Double(observation.deleteCount) / Double(observation.keyboardCount)
        return min(1.0, share / targetShare)
    }
}

/// 键盘和指针都用得多，比例接近
public struct AmbidexterRule: PetSpeciesRule {
    public var minimumTotal = 3_000
    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        guard observation.total >= minimumTotal, observation.pointerCount > 0 else { return 0 }
        let keyboardShare = Double(observation.keyboardCount) / Double(observation.total)
        // 越接近 0.5 越强
        return max(0, 1 - abs(keyboardShare - 0.5) / 0.25)
    }
}

/// 长时间在线：一天里活跃的小时数多
public struct MarathonerRule: PetSpeciesRule {
    public var targetHours = 12
    public init() {}

    public func strength(for observation: PetDayObservation) -> Double {
        min(1.0, Double(observation.activeHours) / Double(targetHours))
    }
}

/// 图鉴。加物种就是往这个数组里加一行。
public enum PetBestiary {
    public static let all: [PetSpecies] = [
        PetSpecies(id: "nightowl", rule: NightOwlRule(), domain: .rhythm),
        PetSpecies(id: "earlybird", rule: EarlyBirdRule(), domain: .rhythm),
        PetSpecies(id: "sprinter", rule: SprinterRule(), domain: .keyboard),
        PetSpecies(id: "shortcut", rule: ShortcutRule(), domain: .keyboard),
        PetSpecies(id: "wanderer", rule: WandererRule(), domain: .pointer),
        PetSpecies(id: "nomad", rule: NomadRule(), domain: .apps),
        PetSpecies(id: "burrower", rule: BurrowerRule(), domain: .apps),
        PetSpecies(id: "reviser", rule: ReviserRule(), domain: .keyboard),
        PetSpecies(id: "ambidexter", rule: AmbidexterRule(), domain: .pointer),
        PetSpecies(id: "marathoner", rule: MarathonerRule(), domain: .rhythm)
    ]

    public static func species(id: String) -> PetSpecies? {
        all.first { $0.id == id }
    }
}
