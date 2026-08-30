import XCTest
@testable import KeyboardWaiterCore

final class PointerMotionCoalescerTests: XCTestCase {
    func testFirstEventCounts() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.35)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
    }

    func testContinuousStreamCountsOnce() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.35)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))

        var time = 100.0
        for _ in 0..<200 {
            time += 0.01
            XCTAssertFalse(coalescer.shouldCount(.move, at: time))
        }
    }

    func testNewStrokeAfterIdleGap() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.35)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
        XCTAssertFalse(coalescer.shouldCount(.move, at: 100.3))
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100.7))
    }

    func testActivitiesTrackedIndependently() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.35)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
        XCTAssertTrue(coalescer.shouldCount(.drag, at: 100.01))
        XCTAssertFalse(coalescer.shouldCount(.move, at: 100.02))
    }

    func testDefaultIdleGap() {
        XCTAssertEqual(PointerMotionCoalescer.defaultIdleGap, 0.4, accuracy: 0.0001)

        var coalescer = PointerMotionCoalescer()
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
        XCTAssertFalse(coalescer.shouldCount(.move, at: 100.3))
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100.8))
    }

    func testResetStartsNewStroke() {
        var coalescer = PointerMotionCoalescer(idleGap: 0.35)
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100))
        coalescer.reset()
        XCTAssertTrue(coalescer.shouldCount(.move, at: 100.01))
    }
}
