import AppKit

final class PointerStatCardView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let countField = NSTextField(labelWithString: "0")

    init(title: String) {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.87, alpha: 1.0).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedRed: 0.84, green: 0.75, blue: 0.55, alpha: 1.0).cgColor

        titleField.stringValue = title
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleField.textColor = NSColor(calibratedRed: 0.28, green: 0.25, blue: 0.18, alpha: 1.0)

        countField.font = NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        countField.textColor = NSColor(calibratedRed: 0.18, green: 0.15, blue: 0.10, alpha: 1.0)

        addSubview(titleField)
        addSubview(countField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        titleField.frame = CGRect(x: 14, y: bounds.height - 24, width: bounds.width - 28, height: 16)
        countField.frame = CGRect(x: 14, y: 14, width: bounds.width - 28, height: bounds.height - 34)
    }

    func setTitle(_ title: String) {
        titleField.stringValue = title
    }

    func update(count: Int) {
        countField.stringValue = CountFormatter.abbreviated(count)
    }
}
