import XCTest
@testable import KeyboardWaiterCore

final class PointerMotionCoalescerTests: XCTestCase {
    func testFirstEventCounts() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.2)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
    }

    func testIdleGapIsLiveAdjustable() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.2)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100.3))

        coalescer.idleGap = 1.0
        XCTAssertFalse(coalescer.shouldCount(.move, at: 100.6))
        XCTAssertTrue(coalescer.shouldCount(.move, at: 101.7))
    }

    func testContinuousStreamCountsOnce() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.2)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))

        var time = 100.0
        for _ in 0..<200 {
            time += 0.01
            XCTAssertFalse(coalescer.shouldCount(.move, at: time))
        }
    }

    func testNewStrokeAfterIdleGap() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.2)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
        XCTAssertFalse(coalescer.shouldCount(.move, at: 100.15))
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100.5))
    }

    func testActivitiesTrackedIndependently() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.2)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
        XCTAssertTrue(coalescer.shouldCount(.drag, at: 100.01))
        XCTAssertFalse(coalescer.shouldCount(.move, at: 100.02))
    }

    func testResetStartsNewStroke() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.2)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
        coalescer.reset()
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100.01))
    }
}
