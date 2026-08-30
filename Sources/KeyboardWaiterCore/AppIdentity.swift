import AppKit

/// 当前前台应用的身份。统计时给每条记录打上「这是在哪个 App 里按的」。
public enum AppIdentity {
    /// 迁移前的历史数据、锁屏、以及取不到前台应用时都用这个。
    public static let unknownID = "unknown"

    private static var displayNameCache: [String: String] = [:]

    /// bundle id 换成人看得懂的名字。查一次缓存一次——Finder 里改过名的 App 也能拿到正确显示名。
    public static func displayName(for appID: String) -> String {
        guard appID != unknownID else { return AppLocalizer.unknownAppName }
        if let cached = displayNameCache[appID] { return cached }

        let resolved: String
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appID) {
            resolved = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
        } else {
            resolved = fallbackName(for: appID)
        }

        displayNameCache[appID] = resolved
        return resolved
    }

    /// App 没装在这台机器上（导入来的数据、已卸载的应用）时只能从 bundle id 猜。
    /// 最后一段常常是 Desktop/client 这种通用词，那就往前取一段厂商名。
    private static let genericSegments: Set<String> = [
        "desktop", "client", "app", "mac", "macos", "osx", "gui", "ui", "main"
    ]

    private static func fallbackName(for appID: String) -> String {
        let segments = appID.split(separator: ".").map(String.init)
        guard let last = segments.last else { return appID }

        let chosen: String
        if genericSegments.contains(last.lowercased()), segments.count >= 2 {
            chosen = segments[segments.count - 2]
        } else {
            chosen = last
        }

        // 全小写的厂商名首字母大写；本来就有大小写的（Xcode、WeChat）原样保留
        guard chosen == chosen.lowercased() else { return chosen }
        return chosen.prefix(1).uppercased() + chosen.dropFirst()
    }
}

/// 跟踪前台应用。用通知而不是每次事件去查——`frontmostApplication` 不是免费的，
/// 而这个值只在切换应用时才会变。
public final class FrontmostAppTracker {
    public private(set) var currentAppID: String = AppIdentity.unknownID

    private var observer: NSObjectProtocol?

    public init() {
        refresh()

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.currentAppID = Self.identifier(for: app)
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    /// 唤醒、解锁之后兜底刷新一次，防止错过通知。
    public func refresh() {
        currentAppID = Self.identifier(for: NSWorkspace.shared.frontmostApplication)
    }

    private static func identifier(for app: NSRunningApplication?) -> String {
        guard let app else { return AppIdentity.unknownID }
        if let bundleID = app.bundleIdentifier, !bundleID.isEmpty { return bundleID }
        if let name = app.localizedName, !name.isEmpty { return name }
        return AppIdentity.unknownID
    }
}
