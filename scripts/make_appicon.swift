import AppKit

// Renders the KeyboardWaiter app icon (graphite background with a keyboard and
// mouse) to a 1024x1024 PNG. scripts/make_appicon.sh turns it into an .icns.
// Usage: swiftc -O make_appicon.swift -o make_appicon && ./make_appicon <out.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"

func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
    NSColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
}

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let img = NSImage(size: image.size)
    img.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: image.size))
    color.set()
    NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
    img.unlockFocus()
    return img
}

func symbol(_ s: NSSize, name: String, tint: NSColor, widthFrac: CGFloat, cx: CGFloat, cy: CGFloat) {
    let cfg = NSImage.SymbolConfiguration(pointSize: s.width * 0.4, weight: .regular)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { fatalError("missing symbol \(name)") }
    let sym = tinted(base, tint)
    let w = s.width * widthFrac
    let aspect = sym.size.width / max(sym.size.height, 1)
    let h = w / aspect
    sym.draw(in: NSRect(x: s.width*cx - w/2, y: s.height*cy - h/2, width: w, height: h))
}

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let s = NSSize(width: size, height: size)
let light = rgb(238, 241, 247)

// graphite squircle background
let m = size * 0.085
let rect = NSRect(x: m, y: m, width: size - 2*m, height: size - 2*m)
let path = NSBezierPath(roundedRect: rect, xRadius: rect.width*0.2237, yRadius: rect.width*0.2237)
NSGraphicsContext.saveGraphicsState()
path.addClip()
NSGradient(starting: rgb(78, 84, 94), ending: rgb(28, 31, 37))!.draw(in: rect, angle: -90)
NSGradient(starting: NSColor.white.withAlphaComponent(0.16), ending: NSColor.white.withAlphaComponent(0.0))!
    .draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height/2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// keyboard + mouse, side by side (variant B2)
symbol(s, name: "keyboard.fill", tint: light, widthFrac: 0.48, cx: 0.40, cy: 0.50)
symbol(s, name: "computermouse.fill", tint: light, widthFrac: 0.16, cx: 0.74, cy: 0.50)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
