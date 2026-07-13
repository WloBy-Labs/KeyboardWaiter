import Foundation

enum HourlyBucket {
    static let secondsPerHour: Int64 = 3_600

    static func bucketStart(for date: Date) -> Int64 {
        bucketStart(forUnixTime: date.timeIntervalSince1970)
    }

    static func bucketStart(forUnixTime unixTime: TimeInterval) -> Int64 {
        Int64(unixTime) / secondsPerHour * secondsPerHour
    }

    static func date(for bucketStart: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(bucketStart))
    }

    static func todayRange(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    static func last24HoursRange(containing date: Date) -> DateInterval {
        let endBucket = bucketStart(for: date)
        let startBucket = endBucket - (23 * secondsPerHour)
        let start = Self.date(for: startBucket)
        let end = Self.date(for: endBucket + secondsPerHour)
        return DateInterval(start: start, end: end)
    }
}
