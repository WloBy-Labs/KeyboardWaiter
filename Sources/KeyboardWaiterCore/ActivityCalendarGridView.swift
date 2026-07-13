import AppKit

final class ActivityCalendarGridView: NSView {
    private let headerStackView = NSStackView()
    private let gridStackView = NSStackView()
    var onCellClick: ((CalendarGridCell) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.95, alpha: 1.0).cgColor
        layer?.cornerRadius = 20

        headerStackView.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.orientation = .horizontal
        headerStackView.alignment = .centerY
        headerStackView.distribution = .fillEqually
        headerStackView.spacing = 8

        gridStackView.translatesAutoresizingMaskIntoConstraints = false
        gridStackView.orientation = .vertical
        gridStackView.alignment = .leading
        gridStackView.distribution = .fillEqually
        gridStackView.spacing = 8

        addSubview(headerStackView)
        addSubview(gridStackView)

        NSLayoutConstraint.activate([
            headerStackView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            headerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            headerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            headerStackView.heightAnchor.constraint(equalToConstant: 18),

            gridStackView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 10),
            gridStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            gridStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            gridStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(model: CalendarGridModel) {
        clearArrangedSubviews(from: headerStackView)
        clearArrangedSubviews(from: gridStackView)

        if model.headerTitles.isEmpty {
            headerStackView.isHidden = true
        } else {
            headerStackView.isHidden = false

            for title in model.headerTitles {
                let label = NSTextField(labelWithString: title)
                label.alignment = .center
                label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
                label.textColor = NSColor(calibratedRed: 0.42, green: 0.38, blue: 0.30, alpha: 1.0)
                headerStackView.addArrangedSubview(label)
            }
        }

        let maxTotal = model.cells.map(\.total).max() ?? 0
        let rowCount = max(1, Int(ceil(Double(max(model.cells.count, 1)) / Double(model.columns))))

        for rowIndex in 0..<rowCount {
            let rowStackView = NSStackView()
            rowStackView.orientation = .horizontal
            rowStackView.alignment = .centerY
            rowStackView.distribution = .fillEqually
            rowStackView.spacing = 8

            for columnIndex in 0..<model.columns {
                let itemIndex = rowIndex * model.columns + columnIndex

                if itemIndex < model.cells.count {
                    let cellView = ActivityCalendarCellView()
                    cellView.update(model: model.cells[itemIndex], maxTotal: maxTotal)
                    cellView.onClick = onCellClick
                    rowStackView.addArrangedSubview(cellView)
                } else {
                    let placeholder = NSView()
                    placeholder.translatesAutoresizingMaskIntoConstraints = false
                    rowStackView.addArrangedSubview(placeholder)
                }
            }

            gridStackView.addArrangedSubview(rowStackView)
        }
    }

    private func clearArrangedSubviews(from stackView: NSStackView) {
        let views = stackView.arrangedSubviews
        for view in views {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}

private final class ActivityCalendarCellView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let countField = NSTextField(labelWithString: "0")
    private let subtitleField = NSTextField(labelWithString: "")
    private var model: CalendarGridCell?
    var onClick: ((CalendarGridCell) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1

        titleField.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        countField.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        subtitleField.font = NSFont.systemFont(ofSize: 10, weight: .medium)

        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        addGestureRecognizer(clickRecognizer)

        addSubview(titleField)
        addSubview(countField)
        addSubview(subtitleField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        titleField.frame = CGRect(x: 12, y: bounds.height - 24, width: bounds.width - 24, height: 16)
        countField.frame = CGRect(x: 12, y: bounds.height * 0.38, width: bounds.width - 24, height: 20)
        subtitleField.frame = CGRect(x: 12, y: 10, width: bounds.width - 24, height: 14)
    }

    func update(model: CalendarGridCell, maxTotal: Int) {
        self.model = model
        let ratio = maxTotal > 0 ? CGFloat(model.total) / CGFloat(maxTotal) : 0
        let baseRed = CGFloat(0.98 - ratio * 0.18)
        let baseGreen = CGFloat(0.95 - ratio * 0.20)
        let baseBlue = CGFloat(0.87 - ratio * 0.28)
        let alpha = model.isMuted ? 0.48 : 1.0

        layer?.backgroundColor = NSColor(
            calibratedRed: baseRed,
            green: baseGreen,
            blue: baseBlue,
            alpha: alpha
        ).cgColor
        layer?.borderColor = (model.isHighlighted
            ? NSColor(calibratedRed: 0.70, green: 0.52, blue: 0.22, alpha: 1.0)
            : NSColor(calibratedRed: 0.86, green: 0.78, blue: 0.60, alpha: 1.0)
        ).cgColor
        layer?.borderWidth = model.isHighlighted ? 2 : 1

        titleField.stringValue = model.title
        titleField.textColor = NSColor(calibratedRed: 0.24, green: 0.20, blue: 0.15, alpha: alpha)

        countField.stringValue = CountFormatter.abbreviated(model.total)
        countField.textColor = NSColor(calibratedRed: 0.16, green: 0.13, blue: 0.10, alpha: alpha)

        if let subtitle = model.subtitle, !subtitle.isEmpty {
            subtitleField.isHidden = false
            subtitleField.stringValue = subtitle
            subtitleField.textColor = NSColor(calibratedRed: 0.42, green: 0.37, blue: 0.29, alpha: alpha)
        } else {
            subtitleField.isHidden = true
            subtitleField.stringValue = ""
        }
    }

    @objc private func handleClick(_ sender: NSClickGestureRecognizer) {
        guard let model else { return }
        onClick?(model)
    }
}
