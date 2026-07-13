import AppKit
import Foundation

enum KeyboardStatsScope: Int, CaseIterable {
    case today
    case last24Hours
    case allTime

    var title: String {
        AppLocalizer.scopeTitle(self)
    }

    var subtitle: String {
        AppLocalizer.scopeSubtitle(self)
    }

    func dateInterval(relativeTo now: Date) -> DateInterval? {
        switch self {
        case .today:
            return HourlyBucket.todayRange(containing: now)
        case .last24Hours:
            return HourlyBucket.last24HoursRange(containing: now)
        case .allTime:
            return nil
        }
    }
}

final class KeyboardVisualizerWindowController: NSWindowController {
    private let statsStore: StatsStore
    private let keyboardView = KeyboardHeatmapView()
    private let totalLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let pageControl = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    private let scopePopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let activeKeysLabel = NSTextField(labelWithString: "")
    private let pointerSectionLabel = NSTextField(labelWithString: "")
    private let scopeLabel = NSTextField(labelWithString: "")
    private let calendarSectionLabel = NSTextField(labelWithString: "")
    private let calendarTitleLabel = NSTextField(labelWithString: "")
    private let calendarSummaryLabel = NSTextField(labelWithString: "")
    private let calendarGranularityControl = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    private let calendarPreviousButton = NSButton(title: "‹", target: nil, action: nil)
    private let calendarTodayButton = NSButton(title: "", target: nil, action: nil)
    private let calendarNextButton = NSButton(title: "›", target: nil, action: nil)
    private let calendarGridView = ActivityCalendarGridView()
    private let pointerStackView = NSStackView()
    private let keyboardScrollView = NSScrollView()
    private let keyboardPageView = NSView()
    private let pointerPageView = NSView()
    private let calendarPageView = NSView()
    private var pointerCardViews: [String: PointerStatCardView] = [:]
    private var calendarGranularity: CalendarGranularity = .month
    private var calendarReferenceDate = Date()
    private var selectedPageIndex = 0

    init(statsStore: StatsStore) {
        self.statsStore = statsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = AppLocalizer.inputActivityWindowTitle
        window.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.89, alpha: 1.0)
        window.isReleasedWhenClosed = false
        window.center()

        for activity in PointerActivity.allCases {
            pointerCardViews[activity.activityID] = PointerStatCardView(title: activity.displayName)
        }

        super.init(window: window)
        buildInterface(window: window)
        refreshData()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndActivate() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        refreshData()
    }

    func refreshData() {
        let scope = selectedScope
        let dateInterval = scope.dateInterval(relativeTo: Date())
        let keyboardCountMap = statsStore.keyCountMap(in: dateInterval, category: .keyboard)
        let pointerCountMap = statsStore.keyCountMap(in: dateInterval, category: .pointer)

        totalLabel.stringValue = AppLocalizer.inputSummary(
            scope: scope,
            keyboardTotal: CountFormatter.abbreviated(keyboardCountMap.total),
            pointerTotal: CountFormatter.abbreviated(pointerCountMap.total)
        )
        subtitleLabel.stringValue = scope.subtitle

        let activeKeys = KeyboardLayout.trackedKeyIDs.reduce(into: 0) { partialResult, keyID in
            if (keyboardCountMap.countsByKeyID[keyID] ?? 0) > 0 {
                partialResult += 1
            }
        }
        activeKeysLabel.stringValue = AppLocalizer.activeKeys(activeKeys, total: KeyboardLayout.keyCount)

        keyboardView.update(countsByKeyID: keyboardCountMap.countsByKeyID)

        for activity in PointerActivity.allCases {
            pointerCardViews[activity.activityID]?.setTitle(activity.displayName)
            pointerCardViews[activity.activityID]?.update(count: pointerCountMap.countsByKeyID[activity.activityID] ?? 0)
        }

        refreshCalendarData()
    }

    func applyLanguage() {
        window?.title = AppLocalizer.inputActivityWindowTitle
        pointerSectionLabel.stringValue = AppLocalizer.pointerSectionTitle
        calendarSectionLabel.stringValue = AppLocalizer.calendarSectionTitle
        calendarTodayButton.title = AppLocalizer.currentPeriodAction
        scopeLabel.stringValue = AppLocalizer.rangeLabel
        keyboardView.applyLanguage()
        reloadPageTitles()
        reloadScopeMenuTitles()
        reloadCalendarGranularityTitles()
        refreshData()
    }

    private var selectedScope: KeyboardStatsScope {
        KeyboardStatsScope(rawValue: scopePopUpButton.indexOfSelectedItem) ?? .today
    }

    @objc private func scopeChanged(_ sender: Any?) {
        refreshData()
    }

    @objc private func pageChanged(_ sender: Any?) {
        selectedPageIndex = pageControl.selectedSegment
        applySelectedPage()
    }

    @objc private func calendarGranularityChanged(_ sender: Any?) {
        calendarGranularity = CalendarGranularity(rawValue: calendarGranularityControl.selectedSegment) ?? .month
        refreshCalendarData()
    }

    @objc private func previousCalendarPeriod(_ sender: Any?) {
        calendarReferenceDate = ActivityCalendarBuilder.shiftedReferenceDate(from: calendarReferenceDate, granularity: calendarGranularity, step: -1)
        refreshCalendarData()
    }

    @objc private func nextCalendarPeriod(_ sender: Any?) {
        calendarReferenceDate = ActivityCalendarBuilder.shiftedReferenceDate(from: calendarReferenceDate, granularity: calendarGranularity, step: 1)
        refreshCalendarData()
    }

    @objc private func resetCalendarPeriod(_ sender: Any?) {
        calendarReferenceDate = Date()
        refreshCalendarData()
    }

    private func buildInterface(window: NSWindow) {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.89, alpha: 1.0).cgColor
        window.contentView = rootView

        let headerPanel = NSView()
        headerPanel.translatesAutoresizingMaskIntoConstraints = false
        headerPanel.wantsLayer = true
        headerPanel.layer?.backgroundColor = NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.78, alpha: 1.0).cgColor
        headerPanel.layer?.cornerRadius = 22

        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        totalLabel.textColor = NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.12, alpha: 1.0)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = NSColor(calibratedRed: 0.30, green: 0.28, blue: 0.22, alpha: 1.0)

        activeKeysLabel.translatesAutoresizingMaskIntoConstraints = false
        activeKeysLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        activeKeysLabel.textColor = NSColor(calibratedRed: 0.34, green: 0.31, blue: 0.24, alpha: 1.0)

        scopeLabel.translatesAutoresizingMaskIntoConstraints = false
        scopeLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        scopeLabel.textColor = NSColor(calibratedRed: 0.34, green: 0.31, blue: 0.24, alpha: 1.0)

        scopePopUpButton.translatesAutoresizingMaskIntoConstraints = false
        scopePopUpButton.target = self
        scopePopUpButton.action = #selector(scopeChanged(_:))

        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.target = self
        pageControl.action = #selector(pageChanged(_:))

        pointerSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        pointerSectionLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        pointerSectionLabel.textColor = NSColor(calibratedRed: 0.28, green: 0.25, blue: 0.18, alpha: 1.0)

        pointerStackView.translatesAutoresizingMaskIntoConstraints = false
        pointerStackView.orientation = .horizontal
        pointerStackView.alignment = .centerY
        pointerStackView.distribution = .fillEqually
        pointerStackView.spacing = 10

        for activity in PointerActivity.allCases {
            if let cardView = pointerCardViews[activity.activityID] {
                pointerStackView.addArrangedSubview(cardView)
            }
        }

        calendarSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        calendarSectionLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        calendarSectionLabel.textColor = NSColor(calibratedRed: 0.28, green: 0.25, blue: 0.18, alpha: 1.0)

        calendarTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        calendarTitleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        calendarTitleLabel.textColor = NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.12, alpha: 1.0)

        calendarSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        calendarSummaryLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        calendarSummaryLabel.textColor = NSColor(calibratedRed: 0.34, green: 0.31, blue: 0.24, alpha: 1.0)

        calendarGranularityControl.translatesAutoresizingMaskIntoConstraints = false
        calendarGranularityControl.target = self
        calendarGranularityControl.action = #selector(calendarGranularityChanged(_:))

        for button in [calendarPreviousButton, calendarTodayButton, calendarNextButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
        }
        calendarPreviousButton.target = self
        calendarPreviousButton.action = #selector(previousCalendarPeriod(_:))
        calendarTodayButton.target = self
        calendarTodayButton.action = #selector(resetCalendarPeriod(_:))
        calendarNextButton.target = self
        calendarNextButton.action = #selector(nextCalendarPeriod(_:))

        calendarGridView.translatesAutoresizingMaskIntoConstraints = false
        calendarGridView.onCellClick = { [weak self] cell in
            self?.openCalendarCell(cell)
        }

        keyboardPageView.translatesAutoresizingMaskIntoConstraints = false
        pointerPageView.translatesAutoresizingMaskIntoConstraints = false
        calendarPageView.translatesAutoresizingMaskIntoConstraints = false

        keyboardScrollView.translatesAutoresizingMaskIntoConstraints = false
        keyboardScrollView.borderType = .noBorder
        keyboardScrollView.hasVerticalScroller = true
        keyboardScrollView.hasHorizontalScroller = true
        keyboardScrollView.drawsBackground = false

        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.frame = CGRect(origin: .zero, size: keyboardView.intrinsicContentSize)
        keyboardScrollView.documentView = keyboardView

        rootView.addSubview(headerPanel)
        rootView.addSubview(pageControl)
        rootView.addSubview(keyboardPageView)
        rootView.addSubview(pointerPageView)
        rootView.addSubview(calendarPageView)

        headerPanel.addSubview(totalLabel)
        headerPanel.addSubview(subtitleLabel)
        headerPanel.addSubview(activeKeysLabel)
        headerPanel.addSubview(scopeLabel)
        headerPanel.addSubview(scopePopUpButton)

        keyboardPageView.addSubview(keyboardScrollView)

        pointerPageView.addSubview(pointerSectionLabel)
        pointerPageView.addSubview(pointerStackView)

        calendarPageView.addSubview(calendarSectionLabel)
        calendarPageView.addSubview(calendarTitleLabel)
        calendarPageView.addSubview(calendarSummaryLabel)
        calendarPageView.addSubview(calendarGranularityControl)
        calendarPageView.addSubview(calendarPreviousButton)
        calendarPageView.addSubview(calendarTodayButton)
        calendarPageView.addSubview(calendarNextButton)
        calendarPageView.addSubview(calendarGridView)

        applyLanguage()
        applySelectedPage()

        NSLayoutConstraint.activate([
            headerPanel.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 18),
            headerPanel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 18),
            headerPanel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -18),
            headerPanel.heightAnchor.constraint(equalToConstant: 116),

            totalLabel.topAnchor.constraint(equalTo: headerPanel.topAnchor, constant: 18),
            totalLabel.leadingAnchor.constraint(equalTo: headerPanel.leadingAnchor, constant: 20),
            totalLabel.trailingAnchor.constraint(lessThanOrEqualTo: scopeLabel.leadingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: totalLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: scopeLabel.leadingAnchor, constant: -20),

            activeKeysLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            activeKeysLabel.leadingAnchor.constraint(equalTo: totalLabel.leadingAnchor),
            activeKeysLabel.trailingAnchor.constraint(lessThanOrEqualTo: scopeLabel.leadingAnchor, constant: -20),

            scopeLabel.topAnchor.constraint(equalTo: headerPanel.topAnchor, constant: 24),
            scopeLabel.trailingAnchor.constraint(equalTo: scopePopUpButton.leadingAnchor, constant: -10),

            scopePopUpButton.centerYAnchor.constraint(equalTo: scopeLabel.centerYAnchor),
            scopePopUpButton.trailingAnchor.constraint(equalTo: headerPanel.trailingAnchor, constant: -20),
            scopePopUpButton.widthAnchor.constraint(equalToConstant: 180),

            pageControl.topAnchor.constraint(equalTo: headerPanel.bottomAnchor, constant: 14),
            pageControl.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            pageControl.widthAnchor.constraint(equalToConstant: 420),

            keyboardPageView.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 14),
            keyboardPageView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 18),
            keyboardPageView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -18),
            keyboardPageView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -18),

            pointerPageView.topAnchor.constraint(equalTo: keyboardPageView.topAnchor),
            pointerPageView.leadingAnchor.constraint(equalTo: keyboardPageView.leadingAnchor),
            pointerPageView.trailingAnchor.constraint(equalTo: keyboardPageView.trailingAnchor),
            pointerPageView.bottomAnchor.constraint(equalTo: keyboardPageView.bottomAnchor),

            calendarPageView.topAnchor.constraint(equalTo: keyboardPageView.topAnchor),
            calendarPageView.leadingAnchor.constraint(equalTo: keyboardPageView.leadingAnchor),
            calendarPageView.trailingAnchor.constraint(equalTo: keyboardPageView.trailingAnchor),
            calendarPageView.bottomAnchor.constraint(equalTo: keyboardPageView.bottomAnchor),

            keyboardScrollView.topAnchor.constraint(equalTo: keyboardPageView.topAnchor),
            keyboardScrollView.leadingAnchor.constraint(equalTo: keyboardPageView.leadingAnchor),
            keyboardScrollView.trailingAnchor.constraint(equalTo: keyboardPageView.trailingAnchor),
            keyboardScrollView.bottomAnchor.constraint(equalTo: keyboardPageView.bottomAnchor),

            pointerSectionLabel.topAnchor.constraint(equalTo: pointerPageView.topAnchor, constant: 6),
            pointerSectionLabel.leadingAnchor.constraint(equalTo: pointerPageView.leadingAnchor, constant: 6),

            pointerStackView.topAnchor.constraint(equalTo: pointerSectionLabel.bottomAnchor, constant: 8),
            pointerStackView.leadingAnchor.constraint(equalTo: pointerPageView.leadingAnchor, constant: 6),
            pointerStackView.trailingAnchor.constraint(equalTo: pointerPageView.trailingAnchor, constant: -6),
            pointerStackView.heightAnchor.constraint(equalToConstant: 120),

            calendarSectionLabel.topAnchor.constraint(equalTo: calendarPageView.topAnchor, constant: 6),
            calendarSectionLabel.leadingAnchor.constraint(equalTo: calendarPageView.leadingAnchor, constant: 6),

            calendarGranularityControl.centerYAnchor.constraint(equalTo: calendarSectionLabel.centerYAnchor),
            calendarGranularityControl.trailingAnchor.constraint(equalTo: calendarPageView.trailingAnchor, constant: -6),
            calendarGranularityControl.widthAnchor.constraint(equalToConstant: 220),

            calendarTitleLabel.topAnchor.constraint(equalTo: calendarSectionLabel.bottomAnchor, constant: 12),
            calendarTitleLabel.leadingAnchor.constraint(equalTo: calendarSectionLabel.leadingAnchor),

            calendarSummaryLabel.topAnchor.constraint(equalTo: calendarTitleLabel.bottomAnchor, constant: 4),
            calendarSummaryLabel.leadingAnchor.constraint(equalTo: calendarTitleLabel.leadingAnchor),

            calendarNextButton.centerYAnchor.constraint(equalTo: calendarTitleLabel.centerYAnchor),
            calendarNextButton.trailingAnchor.constraint(equalTo: calendarPageView.trailingAnchor, constant: -6),
            calendarNextButton.widthAnchor.constraint(equalToConstant: 42),

            calendarTodayButton.centerYAnchor.constraint(equalTo: calendarTitleLabel.centerYAnchor),
            calendarTodayButton.trailingAnchor.constraint(equalTo: calendarNextButton.leadingAnchor, constant: -8),
            calendarTodayButton.widthAnchor.constraint(equalToConstant: 86),

            calendarPreviousButton.centerYAnchor.constraint(equalTo: calendarTitleLabel.centerYAnchor),
            calendarPreviousButton.trailingAnchor.constraint(equalTo: calendarTodayButton.leadingAnchor, constant: -8),
            calendarPreviousButton.widthAnchor.constraint(equalToConstant: 42),

            calendarGridView.topAnchor.constraint(equalTo: calendarSummaryLabel.bottomAnchor, constant: 12),
            calendarGridView.leadingAnchor.constraint(equalTo: calendarPageView.leadingAnchor),
            calendarGridView.trailingAnchor.constraint(equalTo: calendarPageView.trailingAnchor),
            calendarGridView.bottomAnchor.constraint(equalTo: calendarPageView.bottomAnchor),
            calendarGridView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])
    }

    private func reloadScopeMenuTitles() {
        let selectedIndex = scopePopUpButton.indexOfSelectedItem >= 0 ? scopePopUpButton.indexOfSelectedItem : KeyboardStatsScope.today.rawValue
        scopePopUpButton.removeAllItems()
        scopePopUpButton.addItems(withTitles: KeyboardStatsScope.allCases.map(\.title))
        scopePopUpButton.selectItem(at: selectedIndex)
    }

    private func reloadPageTitles() {
        let titles = [AppLocalizer.keyboardPageTitle, AppLocalizer.pointerPageTitle, AppLocalizer.calendarPageTitle]
        pageControl.segmentCount = titles.count

        for (index, title) in titles.enumerated() {
            pageControl.setLabel(title, forSegment: index)
        }

        pageControl.selectedSegment = selectedPageIndex
    }

    private func applySelectedPage() {
        keyboardPageView.isHidden = selectedPageIndex != 0
        pointerPageView.isHidden = selectedPageIndex != 1
        calendarPageView.isHidden = selectedPageIndex != 2
    }

    private func reloadCalendarGranularityTitles() {
        let selectedIndex = calendarGranularity.rawValue
        calendarGranularityControl.segmentCount = CalendarGranularity.allCases.count

        for granularity in CalendarGranularity.allCases {
            calendarGranularityControl.setLabel(granularity.title, forSegment: granularity.rawValue)
        }

        calendarGranularityControl.selectedSegment = selectedIndex
    }

    private func refreshCalendarData() {
        let range = ActivityCalendarBuilder.queryRange(for: calendarReferenceDate, granularity: calendarGranularity)
        let model = ActivityCalendarBuilder.build(
            referenceDate: calendarReferenceDate,
            granularity: calendarGranularity,
            hourlySeries: statsStore.hourlySeries(in: range),
            locale: AppLanguageStore.current.locale
        )

        calendarTitleLabel.stringValue = model.periodTitle
        calendarSummaryLabel.stringValue = AppLocalizer.calendarSummary(total: CountFormatter.abbreviated(model.total))
        calendarGridView.update(model: model)
    }

    private func openCalendarCell(_ cell: CalendarGridCell) {
        guard let date = cell.representedDate else { return }

        switch calendarGranularity {
        case .year:
            calendarReferenceDate = date
            calendarGranularity = .month
        case .month:
            guard !cell.isMuted else { return }
            calendarReferenceDate = date
            calendarGranularity = .day
        case .day:
            return
        }

        reloadCalendarGranularityTitles()
        refreshCalendarData()
    }
}
