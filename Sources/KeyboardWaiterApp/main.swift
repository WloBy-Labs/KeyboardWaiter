import AppKit

#if SWIFT_PACKAGE
import KeyboardWaiterCore
#endif

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

do {
    let controller = try AppController()
    app.delegate = controller
    app.run()
} catch {
    let alert = NSAlert()
    alert.messageText = AppLocalizer.startupFailureTitle
    alert.informativeText = error.localizedDescription
    alert.alertStyle = .critical
    alert.runModal()
    exit(EXIT_FAILURE)
}
