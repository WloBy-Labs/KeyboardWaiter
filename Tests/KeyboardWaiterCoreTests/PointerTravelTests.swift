import XCTest
@testable import KeyboardWaiterCore

final class PointerTravelTests: XCTestCase {
    func testShortMovesAccumulateUntilOneUnit() {
        var accumulator = PointerTravelAccumulator(pointsPerUnit: 500)
        XCTAssertEqual(accumulator.add(deltaX: 200, deltaY: 0), 0)
        XCTAssertEqual(accumulator.add(deltaX: 200, deltaY: 0), 0)
        XCTAssertEqual(accumulator.add(deltaX: 200, deltaY: 0), 1)
        // 余数 100 点保留，下一次只需再走 400 点就满一个单位。
        XCTAssertEqual(accumulator.add(deltaX: 400, deltaY: 0), 1)
    }

    func testLargeMoveReportsAllWholeUnits() {
        var accumulator = PointerTravelAccumulator(pointsPerUnit: 500)
        XCTAssertEqual(accumulator.add(deltaX: 2500, deltaY: 0), 5)
    }

    func testDiagonalUsesEuclideanDistance() {
        var accumulator = PointerTravelAccumulator(pointsPerUnit: 500)
        XCTAssertEqual(accumulator.add(deltaX: 300, deltaY: 400), 1)
    }

    func testNegativeDeltasStillTravel() {
        var accumulator = PointerTravelAccumulator(pointsPerUnit: 500)
        XCTAssertEqual(accumulator.add(deltaX: -600, deltaY: 0), 1)
    }

    func testZeroDeltaIgnored() {
        var accumulator = PointerTravelAccumulator(pointsPerUnit: 500)
        XCTAssertEqual(accumulator.add(deltaX: 0, deltaY: 0), 0)
    }

    func testResetDropsPendingRemainder() {
        var accumulator = PointerTravelAccumulator(pointsPerUnit: 500)
        XCTAssertEqual(accumulator.add(deltaX: 400, deltaY: 0), 0)
        accumulator.reset()
        XCTAssertEqual(accumulator.add(deltaX: 400, deltaY: 0), 0)
    }

    func testMetersConversion() {
        // 500 点 / (110 点每英寸 / 0.0254 米每英寸) ≈ 0.1155 米
        XCTAssertEqual(PointerTravel.meters(forUnits: 1), 0.1155, accuracy: 0.0005)
        XCTAssertEqual(PointerTravel.meters(forUnits: 100), 11.55, accuracy: 0.05)
    }
}
