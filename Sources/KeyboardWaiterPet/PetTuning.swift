import Foundation

/// 养成系统的全部可调参数集中在这里。
///
/// 这个系统一定会反复调，所以规则是：**调整只改这个文件里的数字，不动 PetGrowth 的逻辑**。
/// 测试断言的是性质（乱敲不如正常打字、坚持胜过爆发），不是具体数值，
/// 所以调参不会把测试调红。
public struct PetTuning: Equatable {
    // MARK: 单日成长值的三个分量

    /// 按键种类达到这个数就拿满「多样性」分。乱敲一个键永远只有 1 种。
    public var varietyTarget: Double = 20
    /// 有输入的小时数达到这个数就拿满「分布」分。衡量的是分散而不是集中。
    public var spreadTarget: Double = 5
    /// 总次数达到这个数就拿满「总量」分，而且它占比最低。
    public var volumeTarget: Double = 2_000

    public var varietyWeight: Double = 0.4
    public var spreadWeight: Double = 0.4
    public var volumeWeight: Double = 0.2

    /// 一天最多长这么多，杜绝「今天疯狂打字换成长」。
    public var maxDailyScore: Double = 1.0

    // MARK: 连续天数

    /// 达到这个分数才算「这天出现过」。
    public var activeDayThreshold: Double = 0.15
    /// 每多连一天，当天成长值加成 +2%。
    public var streakBonusPerDay: Double = 0.02
    /// 加成上限 +50%。
    public var maxStreakBonus: Double = 0.5
    /// 连续多少天算一个里程碑（宠物会庆祝）。
    public var streakMilestone: Int = 7

    // MARK: 阶段门槛（累计成长值，一个正常使用的日子约得 1.0）

    public var stageThresholds: [Double] = [0, 3, 10, 25, 50]

    // MARK: 分支判定

    /// 用最近多少天的构成判断进化方向。
    public var branchWindowDays: Int = 14
    /// 键盘占比高于此值 → 码字型。
    public var typistKeyboardShare: Double = 0.75
    /// 键盘占比低于此值 → 操作型。
    public var operatorKeyboardShare: Double = 0.45

    // MARK: 心情

    /// 连续这么多个小时都超过强度阈值 → 疲惫。
    public var tiredSustainedHours: Int = 3
    /// 单小时超过这个输入量算「高强度」。
    public var tiredHourlyThreshold: Int = 1_500

    public static let `default` = PetTuning()

    public init() {}
}
