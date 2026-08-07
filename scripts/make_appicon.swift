import AppKit

// 程序化绘制 App 图标：石墨底 + 键盘和鼠标，下方是 WLOBY KB 字标。
// 与 WloBy 其他 App 同一套版式（见 PrWaiter/make-icon.swift），只有底色和图形不同。
//
// 关键点：小尺寸不画字标。macOS 图标常以 16/32px 出现，八个字符横排在那个尺寸下
// 只会糊成一团。.icns 允许每个尺寸用不同画面，所以大尺寸给完整设计，
// 小尺寸只留图形 —— 这也是为什么要逐尺寸渲染而不是画一张大图再缩。
//
// 图形本身在所有尺寸都完整画（和 PrWaiter 一致），不按尺寸丢元素。
//
// 用法：swiftc -O make_appicon.swift -o make_appicon && ./make_appicon <out.iconset>

let wordmarkMinSize: CGFloat = 128

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let bgTop = color(0x4E545E)          // 石墨，沿用 0.8.x 的底色
let bgBottom = color(0x1C1F25)
let glyph = color(0xEEF1F7)
let textMain = color(0xFFFFFF)
let textAccent = color(0xFFB43F)     // 琥珀色，对应界面里的按键热力图

func tinted(_ image: NSImage, _ tint: NSColor) -> NSImage {
    let img = NSImage(size: image.size)
    img.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: image.size))
    tint.set()
    NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
    img.unlockFocus()
    return img
}

func render(size px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // 画布是 bottom-left 原点，统一用「从顶部量」的坐标再翻过去
    func fromTop(_ y: CGFloat) -> CGFloat { s - y }

    // 圆角方块底：macOS 图标本体不铺满画布，四周留白
    let inset = s * 0.085
    let side = s - inset * 2
    let plate = NSRect(x: inset, y: inset, width: side, height: side)
    let radius = side * 0.2235

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius).addClip()
    NSGradient(starting: bgTop, ending: bgBottom)!.draw(in: plate, angle: -90)
    // 上半部一层很淡的高光，让平涂的石墨看起来有体积
    NSGradient(starting: NSColor.white.withAlphaComponent(0.16),
               ending: NSColor.white.withAlphaComponent(0))!
        .draw(in: NSRect(x: plate.minX, y: plate.midY,
                         width: plate.width, height: plate.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let showWordmark = s >= wordmarkMinSize
    // 有字标时图形上移让出下方文字位；没字标就整块居中
    let glyphCenterFromTop = showWordmark ? side * 0.375 : side / 2
    let cy = fromTop(inset + glyphCenterFromTop)

    // SF Symbol 画到 plate 相对坐标上
    func symbol(_ name: String, centerXFrac: CGFloat, widthFrac: CGFloat) {
        let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.4, weight: .regular)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) else { fatalError("missing symbol \(name)") }
        let sym = tinted(base, glyph)
        let w = side * widthFrac
        let h = w / max(sym.size.width / max(sym.size.height, 1), 0.001)
        sym.draw(in: NSRect(x: plate.minX + side * centerXFrac - w / 2,
                            y: cy - h / 2, width: w, height: h))
    }

    symbol("keyboard.fill", centerXFrac: 0.38, widthFrac: 0.578)
    symbol("computermouse.fill", centerXFrac: 0.79, widthFrac: 0.193)

    if showWordmark {
        let fontSize = side * 0.145
        let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: fontSize * 0.02]
        let text = NSMutableAttributedString(string: "WLOBY", attributes: attrs)
        text.addAttribute(.foregroundColor, value: textMain,
                          range: NSRange(location: 0, length: 5))
        let suffix = NSMutableAttributedString(string: "KB", attributes: attrs)
        suffix.addAttribute(.foregroundColor, value: textAccent,
                            range: NSRange(location: 0, length: 2))
        // 两段之间留一点气口，颜色差别才不显得是一个词
        text.append(NSAttributedString(string: " ", attributes: [.font: font]))
        text.append(suffix)

        // 全是大写字母，用 capHeight 而不是行高来定位 —— 行高含上下留白，
        // 按它居中会让字看起来偏低、和图形之间空出一块
        let tw = text.size().width
        let baseline = fromTop(inset + side * 0.757 + font.capHeight / 2)
        text.draw(at: NSPoint(x: inset + (side - tw) / 2, y: baseline + font.descender))
    }

    return rep.representation(using: .png, properties: [:])!
}

// MARK: 输出 iconset

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

// 同一像素尺寸可能对应两个文件名（如 32 既是 16@2x 也是 32x32）
let entries: [(px: Int, names: [String])] = [
    (16, ["icon_16x16.png"]),
    (32, ["icon_16x16@2x.png", "icon_32x32.png"]),
    (64, ["icon_32x32@2x.png"]),
    (128, ["icon_128x128.png"]),
    (256, ["icon_128x128@2x.png", "icon_256x256.png"]),
    (512, ["icon_256x256@2x.png", "icon_512x512.png"]),
    (1024, ["icon_512x512@2x.png"]),
]

for e in entries {
    let data = render(size: e.px)
    for name in e.names {
        try! data.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
    }
    let note = CGFloat(e.px) >= wordmarkMinSize ? "" : "（无字标）"
    print("  \(e.px)x\(e.px)\(note) → \(e.names.joined(separator: ", "))")
}
print("iconset 已生成：\(out)")
