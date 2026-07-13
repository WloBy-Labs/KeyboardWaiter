import AppKit
import ApplicationServices
import Foundation

enum PermissionStatus: Equatable {
    case granted
    case needsAccess

    var description: String {
        AppLocalizer.permissionDescription(self)
    }
}

final class PermissionService {
    func currentStatus() -> PermissionStatus {
        CGPreflightListenEventAccess() ? .granted : .needsAccess
    }

    @discardableResult
    func requestAccess() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])

        let granted = CGRequestListenEventAccess()
        openSystemSettings()
        return granted
    }

    func openSystemSettings() {
        let targets = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ]

        for target in targets {
            if let url = URL(string: target), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

}
