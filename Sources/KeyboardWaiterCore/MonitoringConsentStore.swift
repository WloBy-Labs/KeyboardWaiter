import Foundation

enum MonitoringConsentStore {
    private static let defaultsKey = "keyboard_waiter.monitoring_consent.version"
    private static let currentVersion = 1

    static var hasConsent: Bool {
        UserDefaults.standard.integer(forKey: defaultsKey) >= currentVersion
    }

    static func grant() {
        UserDefaults.standard.set(currentVersion, forKey: defaultsKey)
    }
}
