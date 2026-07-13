import AppKit

final class KeyboardHeatmapView: NSView {
    private let unitWidth: CGFloat = 58
    private let keyHeight: CGFloat = 66
    private let keyGap: CGFloat = 8
    private let rowGap: CGFloat = 10
    private let padding = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

    private var keyViewsByID: [String: KeyboardKeyView] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.95, alpha: 1.0).cgColor
        layer?.cornerRadius = 22

        for row in KeyboardLayout.rows {
            for item in row {
                guard case .key(let spec) = item else { continue }
                let keyView = KeyboardKeyView(label: AppLocalizer.keycapLabel(for: spec.keyID, fallback: spec.label))
                keyViewsByID[spec.keyID] = keyView
                addSubview(keyView)
            }
        }

        frame.size = intrinsicContentSize
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        var maxWidth: CGFloat = 0

        for row in KeyboardLayout.rows {
            var rowWidth: CGFloat = 0

            for (index, item) in row.enumerated() {
                if index > 0 {
                    rowWidth += keyGap
                }

                switch item {
                case .key(let spec):
                    rowWidth += spec.widthUnits * unitWidth
                case .spacer(let widthUnits):
                    rowWidth += widthUnits * unitWidth
                }
            }

            maxWidth = max(maxWidth, rowWidth)
        }

        let totalHeight = CGFloat(KeyboardLayout.rows.count) * keyHeight
            + CGFloat(max(0, KeyboardLayout.rows.count - 1)) * rowGap
            + padding.top
            + padding.bottom

        return NSSize(width: maxWidth + padding.left + padding.right, height: totalHeight)
    }

    override func layout() {
        super.layout()

        var y = padding.top

        for row in KeyboardLayout.rows {
            var x = padding.left

            for item in row {
                switch item {
                case .key(let spec):
                    let width = spec.widthUnits * unitWidth
                    keyViewsByID[spec.keyID]?.frame = CGRect(x: x, y: y, width: width, height: keyHeight)
                    x += width + keyGap
                case .spacer(let widthUnits):
                    x += widthUnits * unitWidth + keyGap
                }
            }

            y += keyHeight + rowGap
        }
    }

    func update(countsByKeyID: [String: Int]) {
        let maxCount = countsByKeyID.values.max() ?? 0

        for (keyID, keyView) in keyViewsByID {
            keyView.update(count: countsByKeyID[keyID] ?? 0, maxCount: maxCount)
        }
    }

    func applyLanguage() {
        for row in KeyboardLayout.rows {
            for item in row {
                guard case .key(let spec) = item else { continue }
                keyViewsByID[spec.keyID]?.setLabel(AppLocalizer.keycapLabel(for: spec.keyID, fallback: spec.label))
            }
        }
    }
}
