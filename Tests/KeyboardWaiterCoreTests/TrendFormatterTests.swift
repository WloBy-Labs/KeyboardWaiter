import XCTest
@testable import KeyboardWaiterCore

final class TrendFormatterTests: XCTestCase {
    func testSparklineKeepsLengthAndOrder() {
        let sparkline = TrendFormatter.sparkline(for: [0, 3, 6, 9])
        XCTAssertEqual(sparkline.count, 4)
        XCTAssertEqual(sparkline.first, "▁")
    }

    func testSparklineUsesFlatBaselineForAllZeroValues() {
        XCTAssertEqual(TrendFormatter.sparkline(for: [0, 0, 0]), "▁▁▁")
    }
}
