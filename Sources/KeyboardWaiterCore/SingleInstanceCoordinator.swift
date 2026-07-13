import AppKit
import Foundation

enum SingleInstanceCoordinator {
    static func terminateOtherInstances() {
        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let currentBundleIdentifier = Bundle.main.bundleIdentifier
        let currentExecutableName = Bundle.main.executableURL?.lastPathComponent ?? ProcessInfo.processInfo.processName

        let otherInstances = NSWorkspace.shared.runningApplications.filter { application in
            guard application.processIdentifier != currentProcessIdentifier else {
                return false
            }

            if let currentBundleIdentifier,
               application.bundleIdentifier == currentBundleIdentifier {
                return true
            }

            return application.executableURL?.lastPathComponent == currentExecutableName
        }

        guard !otherInstances.isEmpty else {
            return
        }

        for application in otherInstances {
            _ = application.terminate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            for application in otherInstances where !application.isTerminated {
                _ = application.forceTerminate()
            }
        }
    }
}
