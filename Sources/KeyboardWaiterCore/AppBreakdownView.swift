import AppKit

/// 「哪个应用里按的」排行榜：一行一个应用，横条表示占比。
final class AppBreakdownView: NSView {
    private static let rowHeight: CGFloat = 34
    private static let rowSpacing: CGFloat = 6
    private static let maxRows = 12

    private var entries: [AppCount] = []
    private var grandTotal = 0

    private let emptyLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        emptyLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        emptyLabel.textColor = NSColor(calibratedRed: 0.45, green: 0.42, blue: 0.34, alpha: 1.0)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    func update(entries: [AppCount]) {
        self.entries = Array(entries.prefix(Self.maxRows))
        grandTotal = entries.reduce(0) { $0 + $1.total }
        emptyLabel.stringValue = entries.isEmpty ? AppLocalizer.noAppActivityRecorded : ""
        emptyLabel.isHidden = !entries.isEmpty
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        let rows = max(entries.count, 1)
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: CGFloat(rows) * (Self.rowHeight + Self.rowSpacing)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !entries.isEmpty, grandTotal > 0 else { return }

        let nameWidth: CGFloat = 190
        let countsWidth: CGFloat = 210
        let barLeft = nameWidth + 12
        let barRight = bounds.width - countsWidth
        let barMaxWidth = max(barRight - barLeft, 40)
        let topEntryTotal = max(entries.first?.total ?? 1, 1)

        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.18, green: 0.15, blue: 0.10, alpha: 1.0)
        ]
        let countAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor(calibratedRed: 0.38, green: 0.35, blue: 0.28, alpha: 1.0)
        ]

        for (index, entry) in entries.enumerated() {
            let top = CGFloat(index) * (Self.rowHeight + Self.rowSpacing)
            let share = Double(entry.total) / Double(grandTotal)

            let name = AppIdentity.displayName(for: entry.appID) as NSString
            name.draw(
                in: CGRect(x: 4, y: top + 9, width: nameWidth - 8, height: 18),
                withAttributes: nameAttributes
            )

            // 横条按「相对第一名」缩放，差距看得出来；数字给的是占总量的百分比
            let barWidth = max(barMaxWidth * CGFloat(Double(entry.total) / Double(topEntryTotal)), 2)
            let barRect = CGRect(x: barLeft, y: top + 8, width: barWidth, height: 18)
            let barPath = NSBezierPath(roundedRect: barRect, xRadius: 4, yRadius: 4)
            NSColor(calibratedRed: 0.86, green: 0.66, blue: 0.28, alpha: 0.85).setFill()
            barPath.fill()

            let keyboardShare = entry.keyboardCount
            let pointerShare = entry.pointerCount
            let summary = AppLocalizer.appBreakdownRow(
                share: share,
                keyboardCount: keyboardShare,
                pointerCount: pointerShare
            ) as NSString
            summary.draw(
                in: CGRect(x: bounds.width - countsWidth + 8, y: top + 10, width: countsWidth - 12, height: 16),
                withAttributes: countAttributes
            )
        }
    }
}
