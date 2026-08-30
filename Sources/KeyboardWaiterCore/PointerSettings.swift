import Foundation

/// 指针统计的可调参数。
public enum PointerSettings {
    /// 移动分笔间隔：指针静止超过这个时间，下一次移动才算新的一笔。
    /// 点击、拖拽、滚动都有确定的起止信号，是精确计数的，不受这个值影响。
    public static let defaultMotionIdleGapMilliseconds = 200
    public static let motionIdleGapMillisecondsRange = 20...5_000

    private static let motionIdleGapKey = "keyboard_waiter.pointer.motion_idle_gap_ms"

    public static var motionIdleGapMilliseconds: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: motionIdleGapKey)
            guard stored != 0 else { return defaultMotionIdleGapMilliseconds }
            return clampMotionIdleGap(stored)
        }
        set {
            UserDefaults.standard.set(clampMotionIdleGap(newValue), forKey: motionIdleGapKey)
        }
    }

    public static var motionIdleGap: TimeInterval {
        TimeInterval(motionIdleGapMilliseconds) / 1000
    }

    public static func clampMotionIdleGap(_ milliseconds: Int) -> Int {
        min(max(milliseconds, motionIdleGapMillisecondsRange.lowerBound), motionIdleGapMillisecondsRange.upperBound)
    }

    public static func resetMotionIdleGap() {
        UserDefaults.standard.removeObject(forKey: motionIdleGapKey)
    }
}
