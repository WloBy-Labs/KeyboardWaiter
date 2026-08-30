import Foundation

/// 指针移动/拖拽是每秒上百次的连续事件流。这里按空闲间隔把它们切成"一次滑动"：
/// 同一种活动两次事件的间隔超过 idleGap 时，才算作新的一次操作。
public struct PointerMotionCoalescer {
    public static let defaultIdleGap: TimeInterval = 0.4

    private let idleGap: TimeInterval
    private var lastEventTimes: [PointerActivity: TimeInterval] = [:]

    public init(idleGap: TimeInterval = PointerMotionCoalescer.defaultIdleGap) {
        self.idleGap = idleGap
    }

    public mutating func shouldCount(_ activity: PointerActivity, at time: TimeInterval) -> Bool {
        defer { lastEventTimes[activity] = time }
        guard let previous = lastEventTimes[activity] else { return true }
        return time - previous > idleGap
    }

    public mutating func reset() {
        lastEventTimes.removeAll()
    }
}
