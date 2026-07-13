import Foundation

struct AppMetadata {
    let version: String
    let buildNumber: String?
    let buildTimestamp: String?

    static let current = AppMetadata(bundle: .main)

    init(bundle: Bundle) {
        let info = bundle.infoDictionary ?? [:]
        version = info["CFBundleShortVersionString"] as? String ?? "dev"
        buildNumber = info["CFBundleVersion"] as? String
        buildTimestamp = info["KeyboardWaiterBuildTimestamp"] as? String
    }

    var menuDisplayString: String {
        AppLocalizer.versionLine(version: version, buildNumber: buildNumber, buildTimestamp: buildTimestamp)
    }
}
