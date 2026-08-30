import XCTest
@testable import KeyboardWaiterCore

final class PointerDragTrackerTests: XCTestCase {
    private let left: Int64 = 0
    private let right: Int64 = 1

    func testOnePressCountsOneDrag() {
        var tracker = PointerDragTracker()
        tracker.pressBegan(button: left)
        XCTAssertTrue(tracker.shouldCountDrag(button: left))
        for _ in 0..<500 {
            XCTAssertFalse(tracker.shouldCountDrag(button: left))
        }
        tracker.pressEnded(button: left)
    }

    func testSecondPressCountsAgainImmediately() {
        var tracker = PointerDragTracker()
        tracker.pressBegan(button: left)
        XCTAssertTrue(tracker.shouldCountDrag(button: left))
        tracker.pressEnded(button: left)

        // 松开后马上再拖一次，哪怕间隔为零也要算第二次。
        tracker.pressBegan(button: left)
        XCTAssertTrue(tracker.shouldCountDrag(button: left))
    }

    func testButtonsTrackedIndependently() {
        var tracker = PointerDragTracker()
        tracker.pressBegan(button: left)
        tracker.pressBegan(button: right)
        XCTAssertTrue(tracker.shouldCountDrag(button: left))
        XCTAssertTrue(tracker.shouldCountDrag(button: right))
        XCTAssertFalse(tracker.shouldCountDrag(button: left))

        tracker.pressEnded(button: left)
        XCTAssertFalse(tracker.shouldCountDrag(button: right))
    }

    func testResetRecoversFromLostMouseUp() {
        var tracker = PointerDragTracker()
        tracker.pressBegan(button: left)
        XCTAssertTrue(tracker.shouldCountDrag(button: left))

        // 事件流断掉，松开事件丢了；重置后不应该卡死在"已计过"状态。
        tracker.reset()
        XCTAssertTrue(tracker.shouldCountDrag(button: left))
    }
}
