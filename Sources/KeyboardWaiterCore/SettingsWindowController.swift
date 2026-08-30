import AppKit

final class SettingsWindowController: NSWindowController {
    /// 数值变化时回调，参数是毫秒。改动立即生效，没有"应用"按钮。
    var onMotionIdleGapChange: ((Int) -> Void)?

    private let pointerSectionLabel = NSTextField(labelWithString: "")
    private let idleGapLabel = NSTextField(labelWithString: "")
    private let idleGapField = NSTextField()
    private let idleGapUnitLabel = NSTextField(labelWithString: "")
    private let idleGapStepper = NSStepper()
    private let idleGapHelpLabel = NSTextField(wrappingLabelWithString: "")
    private let exactCountingNoteLabel = NSTextField(wrappingLabelWithString: "")
    private let restoreDefaultButton = NSButton()

    private static let contentWidth: CGFloat = 460

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: SettingsWindowController.contentWidth, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.89, alpha: 1.0)
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        buildInterface(window: window)
        applyLanguage()
        reloadValue()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate() {
        reloadValue()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applyLanguage() {
        window?.title = AppLocalizer.settingsWindowTitle
        pointerSectionLabel.stringValue = AppLocalizer.settingsPointerSectionTitle
        idleGapLabel.stringValue = AppLocalizer.motionIdleGapLabel
        idleGapUnitLabel.stringValue = AppLocalizer.millisecondsUnit
        idleGapHelpLabel.stringValue = AppLocalizer.motionIdleGapHelp
        exactCountingNoteLabel.stringValue = AppLocalizer.exactCountingNote
        restoreDefaultButton.title = AppLocalizer.restoreDefaultAction(
            milliseconds: PointerSettings.defaultMotionIdleGapMilliseconds
        )

        // 说明文字换行后的高度随语言变化，窗口跟着收紧，不留大片空白。
        resizeToFitContent()
    }

    private func resizeToFitContent() {
        guard let window, let contentView = window.contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        let height = contentView.fittingSize.height
        guard height > 0 else { return }

        window.setContentSize(NSSize(width: Self.contentWidth, height: height))
    }

    private func buildInterface(window: NSWindow) {
        guard let contentView = window.contentView else { return }

        pointerSectionLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        pointerSectionLabel.textColor = NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.12, alpha: 1.0)

        idleGapLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: PointerSettings.motionIdleGapMillisecondsRange.lowerBound)
        formatter.maximum = NSNumber(value: PointerSettings.motionIdleGapMillisecondsRange.upperBound)

        idleGapField.formatter = formatter
        idleGapField.alignment = .right
        idleGapField.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        idleGapField.target = self
        idleGapField.action = #selector(idleGapFieldChanged(_:))

        idleGapUnitLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        idleGapUnitLabel.textColor = NSColor(calibratedRed: 0.34, green: 0.31, blue: 0.24, alpha: 1.0)

        idleGapStepper.minValue = Double(PointerSettings.motionIdleGapMillisecondsRange.lowerBound)
        idleGapStepper.maxValue = Double(PointerSettings.motionIdleGapMillisecondsRange.upperBound)
        idleGapStepper.increment = 10
        idleGapStepper.valueWraps = false
        idleGapStepper.target = self
        idleGapStepper.action = #selector(idleGapStepperChanged(_:))

        for label in [idleGapHelpLabel, exactCountingNoteLabel] {
            label.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            label.textColor = NSColor(calibratedRed: 0.38, green: 0.35, blue: 0.28, alpha: 1.0)
        }

        restoreDefaultButton.bezelStyle = .rounded
        restoreDefaultButton.target = self
        restoreDefaultButton.action = #selector(restoreDefault(_:))

        let views = [
            pointerSectionLabel, idleGapLabel, idleGapField, idleGapUnitLabel,
            idleGapStepper, idleGapHelpLabel, exactCountingNoteLabel, restoreDefaultButton
        ]

        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            pointerSectionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            pointerSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            idleGapLabel.topAnchor.constraint(equalTo: pointerSectionLabel.bottomAnchor, constant: 16),
            idleGapLabel.leadingAnchor.constraint(equalTo: pointerSectionLabel.leadingAnchor),

            idleGapField.centerYAnchor.constraint(equalTo: idleGapLabel.centerYAnchor),
            idleGapField.leadingAnchor.constraint(equalTo: idleGapLabel.trailingAnchor, constant: 12),
            idleGapField.widthAnchor.constraint(equalToConstant: 70),

            idleGapUnitLabel.centerYAnchor.constraint(equalTo: idleGapLabel.centerYAnchor),
            idleGapUnitLabel.leadingAnchor.constraint(equalTo: idleGapField.trailingAnchor, constant: 6),

            idleGapStepper.centerYAnchor.constraint(equalTo: idleGapLabel.centerYAnchor),
            idleGapStepper.leadingAnchor.constraint(equalTo: idleGapUnitLabel.trailingAnchor, constant: 8),

            idleGapHelpLabel.topAnchor.constraint(equalTo: idleGapLabel.bottomAnchor, constant: 12),
            idleGapHelpLabel.leadingAnchor.constraint(equalTo: pointerSectionLabel.leadingAnchor),
            idleGapHelpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            exactCountingNoteLabel.topAnchor.constraint(equalTo: idleGapHelpLabel.bottomAnchor, constant: 10),
            exactCountingNoteLabel.leadingAnchor.constraint(equalTo: pointerSectionLabel.leadingAnchor),
            exactCountingNoteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            restoreDefaultButton.topAnchor.constraint(equalTo: exactCountingNoteLabel.bottomAnchor, constant: 18),
            restoreDefaultButton.leadingAnchor.constraint(equalTo: pointerSectionLabel.leadingAnchor),
            restoreDefaultButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func reloadValue() {
        let milliseconds = PointerSettings.motionIdleGapMilliseconds
        idleGapField.integerValue = milliseconds
        idleGapStepper.integerValue = milliseconds
    }

    private func apply(milliseconds: Int) {
        let clamped = PointerSettings.clampMotionIdleGap(milliseconds)
        PointerSettings.motionIdleGapMilliseconds = clamped
        idleGapField.integerValue = clamped
        idleGapStepper.integerValue = clamped
        onMotionIdleGapChange?(clamped)
    }

    @objc private func idleGapFieldChanged(_ sender: NSTextField) {
        apply(milliseconds: sender.integerValue)
    }

    @objc private func idleGapStepperChanged(_ sender: NSStepper) {
        apply(milliseconds: sender.integerValue)
    }

    @objc private func restoreDefault(_ sender: Any?) {
        PointerSettings.resetMotionIdleGap()
        reloadValue()
        onMotionIdleGapChange?(PointerSettings.motionIdleGapMilliseconds)
    }
}
