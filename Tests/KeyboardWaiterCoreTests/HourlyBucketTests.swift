import Foundation
import XCTest
@testable import KeyboardWaiterCore

final class HourlyBucketTests: XCTestCase {
    func testBucketStartRoundsDownToHour() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 3
        components.day = 26
        components.hour = 17
        components.minute = 42
        components.second = 18

        let date = components.date!
        let bucket = HourlyBucket.bucketStart(for: date)
        let roundedDate = HourlyBucket.date(for: bucket)

        XCTAssertEqual(roundedDate.timeIntervalSince1970, 1_774_547_600)
    }

    func testLast24HoursRangeContains24Buckets() {
        let date = Date(timeIntervalSince1970: 1_774_548_938)
        let range = HourlyBucket.last24HoursRange(containing: date)
        let startBucket = HourlyBucket.bucketStart(for: range.start)
        let endBucketExclusive = HourlyBucket.bucketStart(forUnixTime: range.end.timeIntervalSince1970 - 0.001) + HourlyBucket.secondsPerHour
        let bucketCount = Int((endBucketExclusive - startBucket) / HourlyBucket.secondsPerHour)

        XCTAssertEqual(bucketCount, 24)
    }
}
