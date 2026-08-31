import Foundation

/// 图鉴的发现记录。这是整个系统里唯一需要落盘的状态——
/// 发现过就是发现过，不会因为后来不这么用了就消失。
public enum PetDiscoveryStore {
    private static let discoveriesKey = "keyboard_waiter.pet.discoveries"
    private static let lastEvaluatedDayKey = "keyboard_waiter.pet.last_evaluated_day"

    /// 物种 id → 发现那天的自然日起点
    public static var discoveries: [String: Int64] {
        get {
            guard let raw = UserDefaults.standard.dictionary(forKey: discoveriesKey) else { return [:] }
            return raw.compactMapValues { value in
                (value as? NSNumber)?.int64Value
            }
        }
        set {
            UserDefaults.standard.set(
                newValue.mapValues { NSNumber(value: $0) },
                forKey: discoveriesKey
            )
        }
    }

    /// 已经评估到哪一天了。应用关掉几天再打开也能把中间补上。
    public static var lastEvaluatedDay: Int64? {
        get {
            let value = UserDefaults.standard.object(forKey: lastEvaluatedDayKey) as? NSNumber
            return value?.int64Value
        }
        set {
            guard let newValue else {
                UserDefaults.standard.removeObject(forKey: lastEvaluatedDayKey)
                return
            }
            UserDefaults.standard.set(NSNumber(value: newValue), forKey: lastEvaluatedDayKey)
        }
    }

    public static func record(speciesID: String, on dayStart: Int64) {
        var current = discoveries
        guard current[speciesID] == nil else { return }
        current[speciesID] = dayStart
        discoveries = current
    }

    public static func reset() {
        UserDefaults.standard.removeObject(forKey: discoveriesKey)
        UserDefaults.standard.removeObject(forKey: lastEvaluatedDayKey)
    }
}
