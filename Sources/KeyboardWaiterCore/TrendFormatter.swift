import Foundation

enum TrendFormatter {
    private static let blocks = Array("▁▂▃▄▅▆▇█")

    static func sparkline(for values: [Int]) -> String {
        guard !values.isEmpty else { return "" }
        guard let maxValue = values.max(), maxValue > 0 else {
            return String(repeating: String(blocks[0]), count: values.count)
        }

        return values
            .map { value -> String in
                let scaled = Int(round(Double(value) / Double(maxValue) * Double(blocks.count - 1)))
                return String(blocks[max(0, min(blocks.count - 1, scaled))])
            }
            .joined()
    }

    static func hourLabel(for bucketStart: Int64) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: HourlyBucket.date(for: bucketStart))
    }
}
