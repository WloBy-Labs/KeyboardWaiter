import XCTest
@testable import KeyboardWaiterCore

final class PointerSettingsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PointerSettings.resetMotionIdleGap()
    }

    override func tearDown() {
        PointerSettings.resetMotionIdleGap()
        super.tearDown()
    }

    func testDefaultIsTwoHundredMilliseconds() {
        XCTAssertEqual(PointerSettings.defaultMotionIdleGapMilliseconds, 200)
        XCTAssertEqual(PointerSettings.motionIdleGapMilliseconds, 200)
        XCTAssertEqual(PointerSettings.motionIdleGap, 0.2, accuracy: 0.0001)
    }

    func testStoresAndReadsBackValue() {
        PointerSettings.motionIdleGapMilliseconds = 350
        XCTAssertEqual(PointerSettings.motionIdleGapMilliseconds, 350)
        XCTAssertEqual(PointerSettings.motionIdleGap, 0.35, accuracy: 0.0001)
    }

    func testClampsOutOfRangeValues() {
        PointerSettings.motionIdleGapMilliseconds = 1
        XCTAssertEqual(PointerSettings.motionIdleGapMilliseconds, PointerSettings.motionIdleGapMillisecondsRange.lowerBound)

        PointerSettings.motionIdleGapMilliseconds = 999_999
        XCTAssertEqual(PointerSettings.motionIdleGapMilliseconds, PointerSettings.motionIdleGapMillisecondsRange.upperBound)
    }

    func testResetRestoresDefault() {
        PointerSettings.motionIdleGapMilliseconds = 900
        PointerSettings.resetMotionIdleGap()
        XCTAssertEqual(PointerSettings.motionIdleGapMilliseconds, 200)
    }
}
