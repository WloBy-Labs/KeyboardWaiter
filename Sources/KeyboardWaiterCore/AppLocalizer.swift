import CoreGraphics
import Foundation

enum AppLocalizer {
    private static var language: AppLanguage {
        AppLanguageStore.current
    }

    static var languageMenuTitle: String {
        switch language {
        case .english:
            return "Language"
        case .simplifiedChinese:
            return "语言"
        }
    }

    static var startupFailureTitle: String {
        switch language {
        case .english:
            return "Keyboard Waiter failed to start"
        case .simplifiedChinese:
            return "Keyboard Waiter 启动失败"
        }
    }

    static func permissionDescription(_ status: PermissionStatus) -> String {
        switch (language, status) {
        case (.english, .granted):
            return "Granted"
        case (.english, .needsAccess):
            return "Needs Input Monitoring"
        case (.simplifiedChinese, .granted):
            return "已授权"
        case (.simplifiedChinese, .needsAccess):
            return "需要输入监控权限"
        }
    }

    static func versionLine(version: String, buildNumber: String?, buildTimestamp: String?) -> String {
        switch language {
        case .english:
            if let buildTimestamp, !buildTimestamp.isEmpty {
                return "Version \(version) | Built \(buildTimestamp)"
            }

            if let buildNumber, !buildNumber.isEmpty {
                return "Version \(version) | Build \(buildNumber)"
            }

            return "Version \(version)"

        case .simplifiedChinese:
            if let buildTimestamp, !buildTimestamp.isEmpty {
                return "版本 \(version) | 构建于 \(buildTimestamp)"
            }

            if let buildNumber, !buildNumber.isEmpty {
                return "版本 \(version) | 构建号 \(buildNumber)"
            }

            return "版本 \(version)"
        }
    }

    static func menuTodayTotal(_ total: Int) -> String {
        switch language {
        case .english:
            return "Today Total: \(total)"
        case .simplifiedChinese:
            return "今日总数：\(total)"
        }
    }

    static func menuMonitoring(_ text: String) -> String {
        switch language {
        case .english:
            return "Monitoring: \(text)"
        case .simplifiedChinese:
            return "监听状态：\(text)"
        }
    }

    static func menuPermission(_ text: String) -> String {
        switch language {
        case .english:
            return "Permission: \(text)"
        case .simplifiedChinese:
            return "权限状态：\(text)"
        }
    }

    static var grantAccess: String {
        switch language {
        case .english:
            return "Open Input Monitoring…"
        case .simplifiedChinese:
            return "打开输入监控设置…"
        }
    }

    static var topKeysToday: String {
        switch language {
        case .english:
            return "Top Keys Today"
        case .simplifiedChinese:
            return "今日按键排行"
        }
    }

    static func menuSectionTitle(_ title: String, expanded: Bool) -> String {
        switch language {
        case .english:
            return expanded ? "[-] \(title)" : "[+] \(title)"
        case .simplifiedChinese:
            return expanded ? "[-] \(title)" : "[+] \(title)"
        }
    }

    static var noKeyPressesRecorded: String {
        switch language {
        case .english:
            return "No key presses recorded yet"
        case .simplifiedChinese:
            return "还没有按键记录"
        }
    }

    static func pointerTodayTotal(_ total: Int) -> String {
        switch language {
        case .english:
            return "Mouse + Trackpad Today: \(total)"
        case .simplifiedChinese:
            return "今日鼠标/触控板：\(total)"
        }
    }

    static var trend24Hours: String {
        switch language {
        case .english:
            return "24h Trend"
        case .simplifiedChinese:
            return "近 24 小时趋势"
        }
    }

    static func bars(_ sparkline: String) -> String {
        switch language {
        case .english:
            return "Bars: \(sparkline)"
        case .simplifiedChinese:
            return "图形：\(sparkline)"
        }
    }

    static func last24HoursTotal(_ total: Int) -> String {
        switch language {
        case .english:
            return "Last 24h Total: \(total)"
        case .simplifiedChinese:
            return "近 24 小时总数：\(total)"
        }
    }

    static var openInputView: String {
        switch language {
        case .english:
            return "Open Input View"
        case .simplifiedChinese:
            return "打开输入视图"
        }
    }

    static var stopMonitoring: String {
        switch language {
        case .english:
            return "Stop Monitoring"
        case .simplifiedChinese:
            return "停止监听"
        }
    }

    static var startMonitoring: String {
        switch language {
        case .english:
            return "Start Monitoring"
        case .simplifiedChinese:
            return "开始监听"
        }
    }

    static var openPrivacySettings: String {
        switch language {
        case .english:
            return "Open Input Monitoring Settings"
        case .simplifiedChinese:
            return "打开输入监控设置"
        }
    }

    static var openDataFolder: String {
        switch language {
        case .english:
            return "Open Data Folder"
        case .simplifiedChinese:
            return "打开数据目录"
        }
    }

    static var exportStatistics: String {
        switch language {
        case .english:
            return "Export Statistics..."
        case .simplifiedChinese:
            return "导出统计数据..."
        }
    }

    static var importStatistics: String {
        switch language {
        case .english:
            return "Import Statistics..."
        case .simplifiedChinese:
            return "导入统计数据..."
        }
    }

    static var privacyAndData: String {
        switch language {
        case .english:
            return "Privacy & Data…"
        case .simplifiedChinese:
            return "隐私与数据…"
        }
    }

    static var deleteAllStatistics: String {
        switch language {
        case .english:
            return "Delete All Statistics…"
        case .simplifiedChinese:
            return "删除全部统计数据…"
        }
    }

    static var quit: String {
        switch language {
        case .english:
            return "Quit"
        case .simplifiedChinese:
            return "退出"
        }
    }

    static func monitoringStatus(isRunning: Bool, waitingForPermission: Bool) -> String {
        switch language {
        case .english:
            if isRunning { return "On" }
            if waitingForPermission { return "Waiting for permission" }
            return "Off"
        case .simplifiedChinese:
            if isRunning { return "开启" }
            if waitingForPermission { return "等待授权" }
            return "关闭"
        }
    }

    static func statusBarTitle(keyboardTotalText: String, pointerTotalText: String, hasPermission: Bool) -> String {
        if hasPermission {
            return "⌨️ \(keyboardTotalText)  🖱️ \(pointerTotalText)"
        }

        return "⌨️ !  🖱️ !"
    }

    static var resetFailedTitle: String {
        switch language {
        case .english:
            return "Reset failed"
        case .simplifiedChinese:
            return "重置失败"
        }
    }

    static var deleteStatisticsTitle: String {
        switch language {
        case .english:
            return "Delete all saved keyboard statistics?"
        case .simplifiedChinese:
            return "要删除全部已保存的键盘统计吗？"
        }
    }

    static func deleteStatisticsMessage(databasePath: String) -> String {
        switch language {
        case .english:
            return """
            This permanently deletes all locally stored hourly counts from \(databasePath).
            Input Monitoring permission and app settings stay unchanged.
            """
        case .simplifiedChinese:
            return """
            这会永久删除保存在本地的全部小时聚合统计：\(databasePath)
            输入监控权限和应用设置不会变化。
            """
        }
    }

    static var continueAction: String {
        switch language {
        case .english:
            return "Continue"
        case .simplifiedChinese:
            return "继续"
        }
    }

    static var cancelAction: String {
        switch language {
        case .english:
            return "Cancel"
        case .simplifiedChinese:
            return "取消"
        }
    }

    static var finalConfirmationRequired: String {
        switch language {
        case .english:
            return "Final confirmation required"
        case .simplifiedChinese:
            return "需要最终确认"
        }
    }

    static func typeDeleteMessage(confirmationPhrase: String) -> String {
        switch language {
        case .english:
            return "Type \(confirmationPhrase) to permanently remove all saved statistics."
        case .simplifiedChinese:
            return "请输入 \(confirmationPhrase) 以永久删除全部已保存统计。"
        }
    }

    static var deleteDataAction: String {
        switch language {
        case .english:
            return "Delete Data"
        case .simplifiedChinese:
            return "删除数据"
        }
    }

    static var confirmationMismatchTitle: String {
        switch language {
        case .english:
            return "Confirmation text did not match"
        case .simplifiedChinese:
            return "确认文本不匹配"
        }
    }

    static var noStatisticsDeleted: String {
        switch language {
        case .english:
            return "No statistics were deleted."
        case .simplifiedChinese:
            return "没有删除任何统计数据。"
        }
    }

    static var monitoringConsentTitle: String {
        switch language {
        case .english:
            return "Allow KeyboardWaiter to monitor input activity?"
        case .simplifiedChinese:
            return "允许 KeyboardWaiter 统计输入活动吗？"
        }
    }

    static var monitoringConsentAllow: String {
        switch language {
        case .english:
            return "Allow Monitoring"
        case .simplifiedChinese:
            return "允许统计"
        }
    }

    static var monitoringConsentMessage: String {
        switch language {
        case .english:
            return """
            KeyboardWaiter records only aggregated counts for keys, mouse clicks, and trackpad scrolling on this Mac.

            It does not save typed text, passwords, clipboard contents, screenshots, or app content.
            To monitor activity across apps, KeyboardWaiter will next ask for Input Monitoring permission.
            """
        case .simplifiedChinese:
            return """
            KeyboardWaiter 只会在本机记录按键次数、鼠标点击次数和触控板滚动次数的聚合统计。

            它不会保存输入文本、密码、剪贴板内容、截图或应用内容。
            为了统计跨应用输入活动，接下来 KeyboardWaiter 会请求“输入监控”权限。
            """
        }
    }

    static var privacySummaryTitle: String {
        switch language {
        case .english:
            return "Privacy & Data"
        case .simplifiedChinese:
            return "隐私与数据"
        }
    }

    static var privacySummaryMessage: String {
        switch language {
        case .english:
            return """
            KeyboardWaiter stores only aggregated counts for keys, mouse clicks, and trackpad scrolling on this Mac.

            It does not save typed text, passwords, clipboard contents, screenshots, or app content.
            You can stop monitoring at any time from the menu bar.
            """
        case .simplifiedChinese:
            return """
            KeyboardWaiter 只会在本机保存按键次数、鼠标点击次数和触控板滚动次数的聚合统计。

            它不会保存输入文本、密码、剪贴板内容、截图或应用内容。
            你可以随时从菜单栏停止统计。
            """
        }
    }

    static var privacyAccessNeededTitle: String {
        switch language {
        case .english:
            return "KeyboardWaiter needs Input Monitoring"
        case .simplifiedChinese:
            return "KeyboardWaiter 需要输入监控权限"
        }
    }

    static var privacyAccessNeededMessage: String {
        switch language {
        case .english:
            return """
            KeyboardWaiter cannot count keys until Input Monitoring is enabled.

            Open Privacy & Security > Input Monitoring. If an older KeyboardWaiter entry is stuck after an upgrade, remove the stale entry first, then enable the current build again.
            """
        case .simplifiedChinese:
            return """
            KeyboardWaiter 需要启用“输入监控”后才能统计按键。

            请打开“隐私与安全性 > 输入监控”。如果升级后残留了旧的 KeyboardWaiter 条目，先删除旧条目，再重新勾选当前这一版。
            """
        }
    }

    static var laterAction: String {
        switch language {
        case .english:
            return "Later"
        case .simplifiedChinese:
            return "稍后"
        }
    }

    static var currentPeriodAction: String {
        switch language {
        case .english:
            return "Current"
        case .simplifiedChinese:
            return "当前"
        }
    }

    static func pointerActivityName(_ activity: PointerActivity) -> String {
        switch (language, activity) {
        case (.english, .leftClick):
            return "Left Click"
        case (.english, .rightClick):
            return "Right Click"
        case (.english, .otherClick):
            return "Other Click"
        case (.english, .scrollUp):
            return "Scroll Up"
        case (.english, .scrollDown):
            return "Scroll Down"
        case (.simplifiedChinese, .leftClick):
            return "左键点击"
        case (.simplifiedChinese, .rightClick):
            return "右键点击"
        case (.simplifiedChinese, .otherClick):
            return "其他点击"
        case (.simplifiedChinese, .scrollUp):
            return "向上滚动"
        case (.simplifiedChinese, .scrollDown):
            return "向下滚动"
        }
    }

    static func scopeTitle(_ scope: KeyboardStatsScope) -> String {
        switch (language, scope) {
        case (.english, .today):
            return "Today"
        case (.english, .last24Hours):
            return "Last 24 Hours"
        case (.english, .allTime):
            return "All Time"
        case (.simplifiedChinese, .today):
            return "今天"
        case (.simplifiedChinese, .last24Hours):
            return "最近 24 小时"
        case (.simplifiedChinese, .allTime):
            return "全部历史"
        }
    }

    static func scopeSubtitle(_ scope: KeyboardStatsScope) -> String {
        switch (language, scope) {
        case (.english, .today):
            return "Keyboard heatmap for key presses captured since midnight."
        case (.english, .last24Hours):
            return "Rolling 24-hour keyboard heatmap."
        case (.english, .allTime):
            return "Keyboard heatmap across all saved history."
        case (.simplifiedChinese, .today):
            return "显示今天零点以来记录到的键盘热力图。"
        case (.simplifiedChinese, .last24Hours):
            return "显示滚动最近 24 小时的键盘热力图。"
        case (.simplifiedChinese, .allTime):
            return "显示全部历史统计对应的键盘热力图。"
        }
    }

    static var inputActivityWindowTitle: String {
        switch language {
        case .english:
            return "Input Activity"
        case .simplifiedChinese:
            return "输入活动"
        }
    }

    static var calendarSectionTitle: String {
        switch language {
        case .english:
            return "Calendar View"
        case .simplifiedChinese:
            return "日历视图"
        }
    }

    static var keyboardPageTitle: String {
        switch language {
        case .english:
            return "Keyboard"
        case .simplifiedChinese:
            return "键盘"
        }
    }

    static var pointerPageTitle: String {
        switch language {
        case .english:
            return "Mouse"
        case .simplifiedChinese:
            return "鼠标"
        }
    }

    static var calendarPageTitle: String {
        switch language {
        case .english:
            return "Calendar"
        case .simplifiedChinese:
            return "日历"
        }
    }

    static func calendarGranularityTitle(_ granularity: CalendarGranularity) -> String {
        switch (language, granularity) {
        case (.english, .year):
            return "Year"
        case (.english, .month):
            return "Month"
        case (.english, .day):
            return "Day"
        case (.simplifiedChinese, .year):
            return "年"
        case (.simplifiedChinese, .month):
            return "月"
        case (.simplifiedChinese, .day):
            return "日"
        }
    }

    static func calendarSummary(total: String) -> String {
        switch language {
        case .english:
            return "Total input actions: \(total)"
        case .simplifiedChinese:
            return "输入总数：\(total)"
        }
    }

    static func inputSummary(scope: KeyboardStatsScope, keyboardTotal: String, pointerTotal: String) -> String {
        switch language {
        case .english:
            return "\(scopeTitle(scope)): \(keyboardTotal) keys | \(pointerTotal) pointer actions"
        case .simplifiedChinese:
            return "\(scopeTitle(scope))：\(keyboardTotal) 次按键 | \(pointerTotal) 次指针操作"
        }
    }

    static func activeKeys(_ active: Int, total: Int) -> String {
        switch language {
        case .english:
            return "Active keys: \(active)/\(total)"
        case .simplifiedChinese:
            return "已使用按键：\(active)/\(total)"
        }
    }

    static var pointerSectionTitle: String {
        switch language {
        case .english:
            return "Mouse & Trackpad"
        case .simplifiedChinese:
            return "鼠标与触控板"
        }
    }

    static var rangeLabel: String {
        switch language {
        case .english:
            return "Range"
        case .simplifiedChinese:
            return "范围"
        }
    }

    static var exportSuccessTitle: String {
        switch language {
        case .english:
            return "Statistics exported"
        case .simplifiedChinese:
            return "统计数据已导出"
        }
    }

    static func exportSuccessMessage(recordCount: Int, totalCount: Int, path: String) -> String {
        switch language {
        case .english:
            return "Exported \(recordCount) hourly records and \(totalCount) total actions.\n\(path)"
        case .simplifiedChinese:
            return "已导出 \(recordCount) 条小时记录，共 \(totalCount) 次输入。\n\(path)"
        }
    }

    static var exportFailedTitle: String {
        switch language {
        case .english:
            return "Export failed"
        case .simplifiedChinese:
            return "导出失败"
        }
    }

    static var importModeTitle: String {
        switch language {
        case .english:
            return "Choose import mode"
        case .simplifiedChinese:
            return "选择导入方式"
        }
    }

    static func importModeMessage(fileName: String) -> String {
        switch language {
        case .english:
            return "Import \(fileName). Merge adds counts; Replace clears current statistics first."
        case .simplifiedChinese:
            return "导入 \(fileName)。合并会叠加数据；替换会先清空当前统计。"
        }
    }

    static var mergeImportedData: String {
        switch language {
        case .english:
            return "Merge Imported Data"
        case .simplifiedChinese:
            return "合并导入数据"
        }
    }

    static var replaceExistingData: String {
        switch language {
        case .english:
            return "Replace Existing Data"
        case .simplifiedChinese:
            return "替换现有数据"
        }
    }

    static var importSuccessTitle: String {
        switch language {
        case .english:
            return "Statistics imported"
        case .simplifiedChinese:
            return "统计数据已导入"
        }
    }

    static func importSuccessMessage(mode: StatsImportMode, recordCount: Int, totalCount: Int) -> String {
        let modeText: String
        switch (language, mode) {
        case (.english, .merge):
            modeText = "Merged"
        case (.english, .replace):
            modeText = "Replaced"
        case (.simplifiedChinese, .merge):
            modeText = "已合并"
        case (.simplifiedChinese, .replace):
            modeText = "已替换"
        }

        switch language {
        case .english:
            return "\(modeText) \(recordCount) hourly records and \(totalCount) total actions."
        case .simplifiedChinese:
            return "\(modeText) \(recordCount) 条小时记录，共 \(totalCount) 次输入。"
        }
    }

    static var importFailedTitle: String {
        switch language {
        case .english:
            return "Import failed"
        case .simplifiedChinese:
            return "导入失败"
        }
    }

    static func keyDisplayName(for keyCode: CGKeyCode, englishFallback: String) -> String {
        guard language == .simplifiedChinese else {
            return englishFallback
        }

        switch UInt16(keyCode) {
        case 36:
            return "回车"
        case 48:
            return "Tab"
        case 49:
            return "空格"
        case 51:
            return "删除"
        case 53:
            return "Esc"
        case 54:
            return "右命令"
        case 55:
            return "命令"
        case 56:
            return "Shift"
        case 57:
            return "大写锁定"
        case 58:
            return "选项"
        case 59:
            return "控制"
        case 60:
            return "右 Shift"
        case 61:
            return "右选项"
        case 62:
            return "右控制"
        case 63:
            return "Fn"
        case 114:
            return "帮助"
        case 115:
            return "Home"
        case 116:
            return "PgUp"
        case 117:
            return "前删"
        case 119:
            return "End"
        case 121:
            return "PgDn"
        case 123:
            return "左"
        case 124:
            return "右"
        case 125:
            return "下"
        case 126:
            return "上"
        default:
            return englishFallback
        }
    }

    static func keyFallbackName(_ rawValue: UInt16) -> String {
        switch language {
        case .english:
            return "Key \(rawValue)"
        case .simplifiedChinese:
            return "按键 \(rawValue)"
        }
    }

    static func keycapLabel(for keyID: String, fallback: String) -> String {
        guard language == .simplifiedChinese else {
            return fallback
        }

        switch keyID {
        case "kc_36":
            return "回车"
        case "kc_49":
            return "空格"
        case "kc_51":
            return "删除"
        case "kc_57":
            return "大写"
        case "kc_59":
            return "控制"
        case "kc_58":
            return "选项"
        case "kc_55":
            return "命令"
        case "kc_54":
            return "右命令"
        case "kc_61":
            return "右选项"
        case "kc_60":
            return "右 Shift"
        case "kc_123":
            return "左"
        case "kc_124":
            return "右"
        case "kc_125":
            return "下"
        case "kc_126":
            return "上"
        default:
            return fallback
        }
    }
}
