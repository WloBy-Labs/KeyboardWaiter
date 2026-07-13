import Foundation

enum CountFormatter {
    static func abbreviated(_ count: Int) -> String {
        switch count {
        case 0..<1_000:
            return "\(count)"
        case 1_000..<10_000:
            return String(format: "%.1fk", Double(count) / 1_000.0)
        case 10_000..<1_000_000:
            return "\(count / 1_000)k"
        default:
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        }
    }
}
