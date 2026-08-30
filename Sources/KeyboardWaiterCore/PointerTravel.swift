import Foundation

/// 指针行程：把指针移动/拖拽的位移累加起来，按固定单位写进统计库。
/// 它是"距离"而不是"次数"，所以用独立的 mt_ 前缀存放，不参与任何次数总计。
public enum PointerTravel {
    public static let keyIDPrefix = "mt_"
    public static let keyID = "mt_pointer_travel"

    /// 每累计这么多点（point，即逻辑像素）写一个单位。
    /// 500 点约合 11 厘米：写库频率够低，显示精度也足够。
    public static let pointsPerUnit: Double = 500

    /// Retina 屏在默认缩放下大约 110 点/英寸。屏幕密度因机型而异，
    /// 这里取一个固定近似值，换算出来的米数是估算而非精确物理距离。
    public static let pointsPerInch: Double = 110
    public static let pointsPerMeter: Double = pointsPerInch / 0.0254

    public static func meters(forUnits units: Int) -> Double {
        Double(units) * pointsPerUnit / pointsPerMeter
    }
}

/// 把每个移动事件的位移攒起来，攒够一个单位才上报，余数留到下次，不丢精度。
public struct PointerTravelAccumulator {
    private let pointsPerUnit: Double
    private var pendingPoints: Double = 0

    public init(pointsPerUnit: Double = PointerTravel.pointsPerUnit) {
        self.pointsPerUnit = pointsPerUnit
    }

    /// 返回本次应记入统计库的整单位数，不足一个单位时返回 0。
    public mutating func add(deltaX: Double, deltaY: Double) -> Int {
        let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()
        guard distance > 0, distance.isFinite else { return 0 }

        pendingPoints += distance
        guard pendingPoints >= pointsPerUnit else { return 0 }

        let units = (pendingPoints / pointsPerUnit).rounded(.down)
        pendingPoints -= units * pointsPerUnit
        return Int(units)
    }

    public mutating func reset() {
        pendingPoints = 0
    }
}
