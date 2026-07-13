import AppKit
import Foundation

public final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let resetConfirmationPhrase = "DELETE"
    private static let automaticPermissionRequestBuildKey = "keyboard_waiter.permission_request.build"
    private static let topKeysExpandedKey = "keyboard_waiter.menu.top_keys_expanded"
    private static let trendExpandedKey = "keyboard_waiter.menu.trend_expanded"

    private let appMetadata = AppMetadata.current
    private let permissionService = PermissionService()
    private let keyCaptureService = KeyCaptureService()
    private let statsStore: StatsStore
    private let menu = NSMenu()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var refreshTimer: Timer?
    private var keyboardWindowController: KeyboardVisualizerWindowController?
    private var hasShownConsentAlertOnLaunch = false
    private var hasShownPermissionAlert = false
    private var monitoringEnabled: Bool
    private var topKeysExpanded: Bool
    private var trendExpanded: Bool
    private var todayTotalCache: Int
    private var todayPointerTotalCache: Int
    private var currentDayStart: Date

    public init(statsStore: StatsStore? = nil) throws {
        let resolvedStore = try statsStore ?? StatsStore()
        self.statsStore = resolvedStore
        self.monitoringEnabled = MonitoringConsentStore.hasConsent
        self.topKeysExpanded = UserDefaults.standard.bool(forKey: Self.topKeysExpandedKey)
        self.trendExpanded = UserDefaults.standard.bool(forKey: Self.trendExpandedKey)
        self.todayTotalCache = resolvedStore.todayTotal(category: .keyboard)
        self.todayPointerTotalCache = resolvedStore.todayTotal(category: .pointer)
        self.currentDayStart = Calendar.current.startOfDay(for: Date())

        super.init()

        keyCaptureService.onKeyCapture = { [weak self] descriptor in
            self?.handleKeyCapture(descriptor)
        }

        keyCaptureService.onPointerCapture = { [weak self] activity in
            self?.handlePointerCapture(activity)
        }

        keyCaptureService.onTapFailure = { [weak self] in
            DispatchQueue.main.async {
                self?.rebuildMenu()
                self?.refreshTitle()
                self?.showPermissionAlertIfNeeded()
            }
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        SingleInstanceCoordinator.terminateOtherInstances()

        guard let button = statusItem.button else { return }

        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.menu = menu
        menu.delegate = self

        refreshTitle()
        refreshMonitoringState()
        scheduleRefreshTimer()
        continueStartupAuthorizationFlow()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        keyCaptureService.stop()
    }

    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func toggleMonitoring(_ sender: Any?) {
        if monitoringEnabled {
            monitoringEnabled = false
        } else {
            guard requestMonitoringConsent() else {
                refreshMonitoringState()
                refreshTitle()
                rebuildMenu()
                return
            }

            monitoringEnabled = true
        }

        refreshMonitoringState()
        refreshTitle()
        rebuildMenu()

        if monitoringEnabled {
            requestAccessOnLaunchIfNeeded(forcePromptForCurrentBuild: true)
        }
    }

    @objc private func requestAccess(_ sender: Any?) {
        guard requestMonitoringConsent() else { return }
        permissionService.requestAccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshMonitoringState()
            self?.refreshTitle()
            self?.rebuildMenu()
        }
    }

    @objc private func openPrivacySettings(_ sender: Any?) {
        permissionService.openSystemSettings()
    }

    @objc private func openDataFolder(_ sender: Any?) {
        NSWorkspace.shared.open(statsStore.dataDirectoryURL)
    }

    @objc private func exportStatistics(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "KeyboardWaiter-Statistics.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let summary = try statsStore.exportSnapshot(to: url)
            presentInfoAlert(
                title: AppLocalizer.exportSuccessTitle,
                message: AppLocalizer.exportSuccessMessage(recordCount: summary.recordCount, totalCount: summary.totalCount, path: url.path)
            )
        } catch {
            presentErrorAlert(title: AppLocalizer.exportFailedTitle, error: error)
        }
    }

    @objc private func importStatistics(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let mode = chooseImportMode(fileName: url.lastPathComponent) else { return }

        do {
            let summary = try statsStore.importSnapshot(from: url, mode: mode)
            todayTotalCache = statsStore.todayTotal(category: .keyboard)
            todayPointerTotalCache = statsStore.todayTotal(category: .pointer)
            refreshTitle()
            rebuildMenu()
            refreshKeyboardWindow()
            presentInfoAlert(
                title: AppLocalizer.importSuccessTitle,
                message: AppLocalizer.importSuccessMessage(mode: mode, recordCount: summary.recordCount, totalCount: summary.totalCount)
            )
        } catch {
            presentErrorAlert(title: AppLocalizer.importFailedTitle, error: error)
        }
    }

    @objc private func showPrivacySummary(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = AppLocalizer.privacySummaryTitle
        alert.informativeText = AppLocalizer.privacySummaryMessage
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func openKeyboardView(_ sender: Any?) {
        if keyboardWindowController == nil {
            keyboardWindowController = KeyboardVisualizerWindowController(statsStore: statsStore)
        }

        keyboardWindowController?.showAndActivate()
    }

    @objc private func toggleTopKeysSection(_ sender: Any?) {
        topKeysExpanded.toggle()
        UserDefaults.standard.set(topKeysExpanded, forKey: Self.topKeysExpandedKey)
        rebuildMenu()
        reopenMenuAfterSectionToggle()
    }

    @objc private func toggleTrendSection(_ sender: Any?) {
        trendExpanded.toggle()
        UserDefaults.standard.set(trendExpanded, forKey: Self.trendExpandedKey)
        rebuildMenu()
        reopenMenuAfterSectionToggle()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let language = AppLanguage(rawValue: rawValue)
        else {
            return
        }

        AppLanguageStore.set(language)
        rebuildMenu()
        refreshTitle()
        keyboardWindowController?.applyLanguage()
    }

    @objc private func resetStatistics(_ sender: Any?) {
        guard confirmResetRisk() else { return }
        guard confirmResetPhrase() else { return }

        do {
            try statsStore.reset()
            todayTotalCache = 0
            todayPointerTotalCache = 0
            currentDayStart = Calendar.current.startOfDay(for: Date())
            refreshTitle()
            rebuildMenu()
            refreshKeyboardWindow()
        } catch {
            presentErrorAlert(title: "Reset failed", error: error)
        }
    }

    @objc private func quitApplication(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    private func handleKeyCapture(_ descriptor: KeyDescriptor) {
        rolloverIfNeeded(referenceDate: Date())
        todayTotalCache += 1
        statsStore.increment(keyID: descriptor.keyID, at: Date())
        refreshTitle()
        refreshKeyboardWindow()
    }

    private func handlePointerCapture(_ activity: PointerActivity) {
        rolloverIfNeeded(referenceDate: Date())
        todayPointerTotalCache += 1
        statsStore.increment(keyID: activity.activityID, at: Date())
        refreshTitle()
        refreshKeyboardWindow()
    }

    private func scheduleRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.refreshPeriodicState()
        }
    }

    private func refreshPeriodicState() {
        rolloverIfNeeded(referenceDate: Date())
        refreshMonitoringState()
        refreshTitle()
        refreshKeyboardWindow()
    }

    private func rolloverIfNeeded(referenceDate: Date) {
        let latestStartOfDay = Calendar.current.startOfDay(for: referenceDate)
        guard latestStartOfDay != currentDayStart else { return }
        currentDayStart = latestStartOfDay
        todayTotalCache = statsStore.todayTotal(now: referenceDate, category: .keyboard)
        todayPointerTotalCache = statsStore.todayTotal(now: referenceDate, category: .pointer)
    }

    private func refreshMonitoringState() {
        let permissionStatus = permissionService.currentStatus()

        if monitoringEnabled && permissionStatus == .granted {
            if !keyCaptureService.isRunning {
                _ = keyCaptureService.start()
            }
        } else if keyCaptureService.isRunning {
            keyCaptureService.stop()
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let permissionStatus = permissionService.currentStatus()
        addDisabledItem(AppLocalizer.menuTodayTotal(todayTotalCache))
        addDisabledItem(AppLocalizer.menuMonitoring(monitoringStatusText(permissionStatus: permissionStatus)))
        addDisabledItem(AppLocalizer.menuPermission(permissionStatus.description))

        if permissionStatus != .granted {
            addActionItem(AppLocalizer.grantAccess, action: #selector(requestAccess(_:)))
        }

        menu.addItem(.separator())

        addActionItem(AppLocalizer.menuSectionTitle(AppLocalizer.topKeysToday, expanded: topKeysExpanded), action: #selector(toggleTopKeysSection(_:)))
        let todayRange = HourlyBucket.todayRange(containing: Date())
        let todayTopKeys = statsStore.topKeys(in: todayRange, limit: 8, category: .keyboard)

        if topKeysExpanded {
            if todayTopKeys.isEmpty {
                addDisabledItem(AppLocalizer.noKeyPressesRecorded)
            } else {
                for entry in todayTopKeys {
                    let label = KeyTranslator.displayName(for: entry.keyID)
                    addDisabledItem("  \(label): \(entry.count)")
                }
            }
        }

        menu.addItem(.separator())
        let pointerCountMap = statsStore.keyCountMap(in: todayRange, category: .pointer)
        addDisabledItem(AppLocalizer.pointerTodayTotal(pointerCountMap.total))

        menu.addItem(.separator())

        addActionItem(AppLocalizer.menuSectionTitle(AppLocalizer.trend24Hours, expanded: trendExpanded), action: #selector(toggleTrendSection(_:)))
        let trendSeries = statsStore.hourlySeries(in: HourlyBucket.last24HoursRange(containing: Date()))
        let trendValues = trendSeries.map(\.total)
        if trendExpanded {
            addDisabledItem("  \(AppLocalizer.bars(TrendFormatter.sparkline(for: trendValues)))")
            addDisabledItem("  \(AppLocalizer.last24HoursTotal(trendValues.reduce(0, +)))")

            for point in trendSeries.suffix(6) {
                addDisabledItem("  \(TrendFormatter.hourLabel(for: point.bucketStart)): \(point.total)")
            }
        }

        menu.addItem(.separator())
        addLanguageMenu()
        addActionItem(AppLocalizer.openInputView, action: #selector(openKeyboardView(_:)))
        addActionItem(monitoringEnabled ? AppLocalizer.stopMonitoring : AppLocalizer.startMonitoring, action: #selector(toggleMonitoring(_:)))
        addActionItem(AppLocalizer.openPrivacySettings, action: #selector(openPrivacySettings(_:)))
        addActionItem(AppLocalizer.privacyAndData, action: #selector(showPrivacySummary(_:)))
        addActionItem(AppLocalizer.exportStatistics, action: #selector(exportStatistics(_:)))
        addActionItem(AppLocalizer.importStatistics, action: #selector(importStatistics(_:)))
        addActionItem(AppLocalizer.openDataFolder, action: #selector(openDataFolder(_:)))
        addActionItem(AppLocalizer.deleteAllStatistics, action: #selector(resetStatistics(_:)))

        menu.addItem(.separator())
        addDisabledItem(appMetadata.menuDisplayString)
        addActionItem(AppLocalizer.quit, action: #selector(quitApplication(_:)), keyEquivalent: "q")
    }

    private func monitoringStatusText(permissionStatus: PermissionStatus) -> String {
        AppLocalizer.monitoringStatus(
            isRunning: monitoringEnabled && keyCaptureService.isRunning,
            waitingForPermission: monitoringEnabled && permissionStatus != .granted
        )
    }

    private func refreshTitle() {
        statusItem.button?.title = AppLocalizer.statusBarTitle(
            keyboardTotalText: CountFormatter.abbreviated(todayTotalCache),
            pointerTotalText: CountFormatter.abbreviated(todayPointerTotalCache),
            hasPermission: permissionService.currentStatus() == .granted
        )
    }

    private func refreshKeyboardWindow() {
        guard let keyboardWindowController, keyboardWindowController.window?.isVisible == true else {
            return
        }

        keyboardWindowController.refreshData()
    }

    private func confirmResetRisk() -> Bool {
        let alert = NSAlert()
        alert.messageText = AppLocalizer.deleteStatisticsTitle
        alert.informativeText = AppLocalizer.deleteStatisticsMessage(databasePath: statsStore.databaseURL.path)
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLocalizer.continueAction)
        alert.addButton(withTitle: AppLocalizer.cancelAction)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmResetPhrase() -> Bool {
        let alert = NSAlert()
        alert.messageText = AppLocalizer.finalConfirmationRequired
        alert.informativeText = AppLocalizer.typeDeleteMessage(confirmationPhrase: Self.resetConfirmationPhrase)
        alert.alertStyle = .critical
        alert.addButton(withTitle: AppLocalizer.deleteDataAction)
        alert.addButton(withTitle: AppLocalizer.cancelAction)

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        textField.placeholderString = Self.resetConfirmationPhrase
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        let typedPhrase = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard typedPhrase == Self.resetConfirmationPhrase else {
            let mismatchAlert = NSAlert()
            mismatchAlert.messageText = AppLocalizer.confirmationMismatchTitle
            mismatchAlert.informativeText = AppLocalizer.noStatisticsDeleted
            mismatchAlert.alertStyle = .informational
            mismatchAlert.runModal()
            return false
        }

        return true
    }

    private func chooseImportMode(fileName: String) -> StatsImportMode? {
        let alert = NSAlert()
        alert.messageText = AppLocalizer.importModeTitle
        alert.informativeText = AppLocalizer.importModeMessage(fileName: fileName)
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLocalizer.mergeImportedData)
        alert.addButton(withTitle: AppLocalizer.replaceExistingData)
        alert.addButton(withTitle: AppLocalizer.cancelAction)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .merge
        case .alertSecondButtonReturn:
            return .replace
        default:
            return nil
        }
    }

    private func showPermissionAlertIfNeeded() {
        guard !hasShownPermissionAlert else { return }
        guard permissionService.currentStatus() != .granted else { return }

        hasShownPermissionAlert = true

        let alert = NSAlert()
        alert.messageText = AppLocalizer.privacyAccessNeededTitle
        alert.informativeText = AppLocalizer.privacyAccessNeededMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppLocalizer.openPrivacySettings)
        alert.addButton(withTitle: AppLocalizer.laterAction)

        if alert.runModal() == .alertFirstButtonReturn {
            permissionService.requestAccess()
        }
    }

    private func continueStartupAuthorizationFlow() {
        guard requestMonitoringConsentOnLaunchIfNeeded() else {
            refreshMonitoringState()
            refreshTitle()
            rebuildMenu()
            return
        }

        requestAccessOnLaunchIfNeeded()
    }

    private func requestAccessOnLaunchIfNeeded(forcePromptForCurrentBuild: Bool = false) {
        guard permissionService.currentStatus() != .granted else { return }
        guard monitoringEnabled else { return }

        let currentBuildToken = permissionRequestBuildToken
        let defaults = UserDefaults.standard

        if forcePromptForCurrentBuild || defaults.string(forKey: Self.automaticPermissionRequestBuildKey) != currentBuildToken {
            defaults.set(currentBuildToken, forKey: Self.automaticPermissionRequestBuildKey)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, self.permissionService.currentStatus() != .granted else { return }

                _ = self.permissionService.requestAccess()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.refreshMonitoringState()
                    self?.refreshTitle()
                    self?.rebuildMenu()
                    self?.showPermissionAlertIfNeeded()
                }
            }

            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showPermissionAlertIfNeeded()
        }
    }

    private var permissionRequestBuildToken: String {
        [appMetadata.version, appMetadata.buildNumber ?? ""].joined(separator: "|")
    }

    private func requestMonitoringConsentOnLaunchIfNeeded() -> Bool {
        guard !MonitoringConsentStore.hasConsent else { return true }
        guard !hasShownConsentAlertOnLaunch else { return false }

        hasShownConsentAlertOnLaunch = true
        return requestMonitoringConsent()
    }

    private func requestMonitoringConsent() -> Bool {
        guard !MonitoringConsentStore.hasConsent else { return true }

        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])

        let alert = NSAlert()
        alert.messageText = AppLocalizer.monitoringConsentTitle
        alert.informativeText = AppLocalizer.monitoringConsentMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: AppLocalizer.monitoringConsentAllow)
        alert.addButton(withTitle: AppLocalizer.laterAction)

        let accepted = alert.runModal() == .alertFirstButtonReturn
        if accepted {
            MonitoringConsentStore.grant()
            monitoringEnabled = true
        } else {
            monitoringEnabled = false
        }

        return accepted
    }

    private func addLanguageMenu() {
        let languageMenuItem = NSMenuItem(title: AppLocalizer.languageMenuTitle, action: nil, keyEquivalent: "")
        let languageMenu = NSMenu(title: AppLocalizer.languageMenuTitle)

        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.menuTitle, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = AppLanguageStore.current == language ? .on : .off
            languageMenu.addItem(item)
        }

        languageMenuItem.submenu = languageMenu
        menu.addItem(languageMenuItem)
    }

    private func addDisabledItem(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addActionItem(_ title: String, action: Selector, keyEquivalent: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        menu.addItem(item)
    }

    private func reopenMenuAfterSectionToggle() {
        // NSStatusItem menu closes after clicking an action item.
        // Re-open on next run loop so expand/collapse feels in-place.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.statusItem.button?.performClick(nil)
        }
    }

    private func presentErrorAlert(title: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
