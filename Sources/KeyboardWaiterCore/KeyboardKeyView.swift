import AppKit

final class KeyboardKeyView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let countField = NSTextField(labelWithString: "0")

    init(label: String) {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1

        titleField.stringValue = label
        titleField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleField.textColor = NSColor(calibratedWhite: 0.22, alpha: 1.0)
        titleField.lineBreakMode = .byTruncatingTail

        countField.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        countField.alignment = .center
        countField.textColor = NSColor(calibratedWhite: 0.13, alpha: 1.0)

        addSubview(titleField)
        addSubview(countField)
        update(count: 0, maxCount: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        titleField.frame = CGRect(x: 10, y: bounds.height - 20, width: bounds.width - 20, height: 14)
        countField.frame = CGRect(x: 8, y: 12, width: bounds.width - 16, height: bounds.height - 28)
    }

    func setLabel(_ label: String) {
        titleField.stringValue = label
    }

    func update(count: Int, maxCount: Int) {
        countField.stringValue = CountFormatter.abbreviated(count)

        let backgroundColor: NSColor
        let borderColor: NSColor

        if count <= 0 || maxCount <= 0 {
            backgroundColor = NSColor(calibratedRed: 0.93, green: 0.92, blue: 0.89, alpha: 1.0)
            borderColor = NSColor(calibratedRed: 0.84, green: 0.82, blue: 0.78, alpha: 1.0)
        } else {
            let intensity = min(1.0, max(0.15, Double(count) / Double(maxCount)))
            backgroundColor = interpolateColor(
                from: NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.78, alpha: 1.0),
                to: NSColor(calibratedRed: 0.89, green: 0.53, blue: 0.22, alpha: 1.0),
                fraction: intensity
            )
            borderColor = interpolateColor(
                from: NSColor(calibratedRed: 0.88, green: 0.76, blue: 0.48, alpha: 1.0),
                to: NSColor(calibratedRed: 0.67, green: 0.31, blue: 0.10, alpha: 1.0),
                fraction: intensity
            )
        }

        layer?.backgroundColor = backgroundColor.cgColor
        layer?.borderColor = borderColor.cgColor
    }

    private func interpolateColor(from start: NSColor, to end: NSColor, fraction: Double) -> NSColor {
        let clamped = min(1.0, max(0.0, fraction))
        let startRGB = start.usingColorSpace(.deviceRGB) ?? start
        let endRGB = end.usingColorSpace(.deviceRGB) ?? end

        return NSColor(
            calibratedRed: startRGB.redComponent + (endRGB.redComponent - startRGB.redComponent) * clamped,
            green: startRGB.greenComponent + (endRGB.greenComponent - startRGB.greenComponent) * clamped,
            blue: startRGB.blueComponent + (endRGB.blueComponent - startRGB.blueComponent) * clamped,
            alpha: 1.0
        )
    }
}
