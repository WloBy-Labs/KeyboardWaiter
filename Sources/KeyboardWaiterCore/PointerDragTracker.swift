import Foundation

/// 拖拽有确定的边界：按下 → 拖动 → 松开。这里保证一次按下最多记一笔拖拽，
/// 不需要像纯移动那样靠时间间隔去猜。按键号分开跟踪，左键拖拽时右键也能各记各的。
public struct PointerDragTracker {
    private var countedButtons = Set<Int64>()

    public init() {}

    public mutating func pressBegan(button: Int64) {
        countedButtons.remove(button)
    }

    public mutating func pressEnded(button: Int64) {
        countedButtons.remove(button)
    }

    /// 本次拖动事件是否应该记一笔：同一次按下里只有第一个拖动事件返回 true。
    public mutating func shouldCountDrag(button: Int64) -> Bool {
        countedButtons.insert(button).inserted
    }

    /// 事件流断过时调用，避免丢掉的松开事件让某个按键永远记不上拖拽。
    public mutating func reset() {
        countedButtons.removeAll()
    }
}
