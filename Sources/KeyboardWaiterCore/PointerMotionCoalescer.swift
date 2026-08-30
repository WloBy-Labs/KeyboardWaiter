import Foundation

/// 指针移动是每秒上百次的连续事件流，而且没有任何"这一笔开始了"的信号。
/// 这里按空闲间隔把它切成"一次滑动"：静止超过 idleGap 之后的下一个事件才算新的一笔。
/// 只用于纯移动——点击、拖拽、滚动都有确定的起止事件，各自精确计数。
public struct PointerMotionCoalescer {
    /// 间隔可以在设置里改，改完立即生效，已有的计时状态不受影响。
    public var idleGap: TimeInterval

    private var lastEventTimes: [PointerActivity: TimeInterval] = [:]

    public init(idleGap: TimeInterval) {
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
