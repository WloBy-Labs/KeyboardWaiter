import AppKit

/// 代码画的占位形象：十个物种各有一套形状特征，能区分开就行。
/// 目的是让机制先跑起来——美术交付后整个文件可以删掉。
public final class PetPlaceholderSpriteProvider: PetSpriteProvider {
    private let amber = NSColor(calibratedRed: 0.86, green: 0.66, blue: 0.28, alpha: 1.0)
    private let ink = NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.12, alpha: 1.0)

    public init() {}

    public func image(speciesID: String, dormant: Bool, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let alpha: CGFloat = dormant ? 0.45 : 1.0
        let scale = size / 64
        let body = CGRect(x: size * 0.16, y: size * 0.16, width: size * 0.68, height: size * 0.62)

        amber.withAlphaComponent(alpha).setFill()
        ink.withAlphaComponent(alpha).setStroke()

        let path = bodyPath(for: speciesID, in: body)
        path.fill()
        path.lineWidth = 1.6 * scale
        path.stroke()

        drawFace(in: body, dormant: dormant, alpha: alpha, scale: scale)
        drawTrait(for: speciesID, around: body, alpha: alpha, scale: scale)

        return image
    }

    /// 轮廓必须拉开差距——栖息地里只有 40pt，靠配件区分是看不出来的，只有剪影认得出。
    private func bodyPath(for speciesID: String, in rect: CGRect) -> NSBezierPath {
        switch speciesID {
        case "nightowl":                                   // 宽扁，像蹲着的猫头鹰
            return NSBezierPath(ovalIn: rect.insetBy(dx: 0, dy: rect.height * 0.14))

        case "earlybird":                                  // 尖顶三角，像初升的形状
            let path = NSBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.line(to: CGPoint(x: rect.minX, y: rect.minY))
            path.close()
            return path

        case "sprinter":                                   // 后掠的梯形，明显朝右冲
            let path = NSBezierPath()
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY))
            path.line(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18))
            path.line(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.maxY))
            path.line(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.22))
            path.close()
            return path

        case "shortcut":                                   // 正方形，硬边
            return NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.04, dy: 0),
                                xRadius: rect.width * 0.06, yRadius: rect.width * 0.06)

        case "wanderer":                                   // 高瘦，长腿的感觉
            return NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.26, dy: 0),
                                xRadius: rect.width * 0.22, yRadius: rect.width * 0.22)

        case "nomad":                                      // 六边形
            let path = NSBezierPath()
            for index in 0..<6 {
                let angle = (Double(index) * 60 + 30) * .pi / 180
                let point = CGPoint(x: rect.midX + cos(angle) * rect.width * 0.5,
                                    y: rect.midY + sin(angle) * rect.height * 0.5)
                index == 0 ? path.move(to: point) : path.line(to: point)
            }
            path.close()
            return path

        case "burrower":                                   // 半圆，像埋进土里
            let path = NSBezierPath()
            path.appendArc(withCenter: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.1),
                           radius: rect.width * 0.5, startAngle: 0, endAngle: 180)
            path.close()
            return path

        case "reviser":                                    // 缺了一角的方块，被擦掉过
            let path = NSBezierPath()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.3))
            path.line(to: CGPoint(x: rect.maxX - rect.width * 0.34, y: rect.maxY))
            path.line(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.close()
            return path

        case "ambidexter":                                 // 菱形，左右完全对称
            let path = NSBezierPath()
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.line(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.line(to: CGPoint(x: rect.midX, y: rect.minY))
            path.line(to: CGPoint(x: rect.minX, y: rect.midY))
            path.close()
            return path

        case "marathoner":                                 // 竖立的胶囊，站得住
            return NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.2, dy: 0),
                                xRadius: rect.width * 0.3, yRadius: rect.width * 0.3)

        default:
            return NSBezierPath(ovalIn: rect)
        }
    }

    private func drawFace(in rect: CGRect, dormant: Bool, alpha: CGFloat, scale: CGFloat) {
        ink.withAlphaComponent(alpha).setFill()
        ink.withAlphaComponent(alpha).setStroke()

        let eyeY = rect.midY + rect.height * 0.02
        let offset = rect.width * 0.16

        for direction in [-1.0, 1.0] {
            let x = rect.midX + CGFloat(direction) * offset
            if dormant {
                let line = NSBezierPath()
                line.move(to: CGPoint(x: x - rect.width * 0.06, y: eyeY))
                line.line(to: CGPoint(x: x + rect.width * 0.06, y: eyeY))
                line.lineWidth = 1.6 * scale
                line.stroke()
            } else {
                NSBezierPath(ovalIn: CGRect(
                    x: x - rect.width * 0.05, y: eyeY - rect.width * 0.05,
                    width: rect.width * 0.1, height: rect.width * 0.1
                )).fill()
            }
        }
    }

    /// 每个物种一个小特征，方便一眼区分
    private func drawTrait(for speciesID: String, around rect: CGRect, alpha: CGFloat, scale: CGFloat) {
        ink.withAlphaComponent(alpha).setStroke()
        amber.withAlphaComponent(alpha).setFill()

        let path = NSBezierPath()
        path.lineWidth = 1.5 * scale

        switch speciesID {
        case "nightowl":                                   // 头顶月牙
            let moon = NSBezierPath(ovalIn: CGRect(x: rect.midX - rect.width * 0.1, y: rect.maxY,
                                                   width: rect.width * 0.2, height: rect.width * 0.2))
            moon.fill(); moon.stroke()
        case "earlybird":                                  // 头顶光芒
            for angle in stride(from: 40.0, through: 140.0, by: 25.0) {
                let radians = angle * .pi / 180
                path.move(to: CGPoint(x: rect.midX + cos(radians) * rect.width * 0.34,
                                      y: rect.maxY + sin(radians) * rect.width * 0.06))
                path.line(to: CGPoint(x: rect.midX + cos(radians) * rect.width * 0.46,
                                      y: rect.maxY + sin(radians) * rect.width * 0.18))
            }
            path.stroke()
        case "sprinter":                                   // 身后速度线
            for index in 0..<3 {
                let y = rect.minY + rect.height * (0.3 + Double(index) * 0.2)
                path.move(to: CGPoint(x: rect.minX - rect.width * 0.22, y: y))
                path.line(to: CGPoint(x: rect.minX - rect.width * 0.04, y: y))
            }
            path.stroke()
        case "shortcut":                                   // 闪电
            path.move(to: CGPoint(x: rect.midX + rect.width * 0.02, y: rect.maxY + rect.height * 0.22))
            path.line(to: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.maxY + rect.height * 0.04))
            path.line(to: CGPoint(x: rect.midX + rect.width * 0.04, y: rect.maxY + rect.height * 0.06))
            path.line(to: CGPoint(x: rect.midX - rect.width * 0.02, y: rect.maxY - rect.height * 0.1))
            path.stroke()
        case "wanderer":                                   // 脚印
            for index in 0..<2 {
                let dot = NSBezierPath(ovalIn: CGRect(
                    x: rect.minX - rect.width * (0.26 - Double(index) * 0.14),
                    y: rect.minY - rect.height * (0.12 + Double(index) * 0.06),
                    width: rect.width * 0.08, height: rect.width * 0.06))
                dot.fill()
            }
        case "nomad":                                      // 环绕的小点
            for angle in stride(from: 0.0, to: 360.0, by: 90.0) {
                let radians = angle * .pi / 180
                let dot = NSBezierPath(ovalIn: CGRect(
                    x: rect.midX + cos(radians) * rect.width * 0.52 - rect.width * 0.03,
                    y: rect.midY + sin(radians) * rect.width * 0.52 - rect.width * 0.03,
                    width: rect.width * 0.06, height: rect.width * 0.06))
                dot.fill()
            }
        case "burrower":                                   // 脚下土堆
            path.move(to: CGPoint(x: rect.minX - rect.width * 0.1, y: rect.minY - rect.height * 0.06))
            path.curve(to: CGPoint(x: rect.maxX + rect.width * 0.1, y: rect.minY - rect.height * 0.06),
                       controlPoint1: CGPoint(x: rect.midX - rect.width * 0.2, y: rect.minY - rect.height * 0.22),
                       controlPoint2: CGPoint(x: rect.midX + rect.width * 0.2, y: rect.minY - rect.height * 0.22))
            path.stroke()
        case "reviser":                                    // 橡皮擦一样的方块
            let eraser = NSBezierPath(roundedRect: CGRect(
                x: rect.maxX + rect.width * 0.02, y: rect.midY,
                width: rect.width * 0.16, height: rect.width * 0.12), xRadius: 2, yRadius: 2)
            eraser.fill(); eraser.stroke()
        case "ambidexter":                                 // 左右两只手臂
            for direction in [-1.0, 1.0] {
                path.move(to: CGPoint(x: rect.midX + CGFloat(direction) * rect.width * 0.5, y: rect.midY))
                path.line(to: CGPoint(x: rect.midX + CGFloat(direction) * rect.width * 0.66, y: rect.midY + rect.height * 0.12))
            }
            path.stroke()
        case "marathoner":                                 // 头顶的圈
            let ring = NSBezierPath(ovalIn: CGRect(x: rect.midX - rect.width * 0.14, y: rect.maxY + rect.height * 0.04,
                                                   width: rect.width * 0.28, height: rect.width * 0.1))
            ring.lineWidth = 1.5 * scale
            ring.stroke()
        default:
            break
        }
    }
}
