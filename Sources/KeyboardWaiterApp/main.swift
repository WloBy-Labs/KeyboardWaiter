import AppKit

#if SWIFT_PACKAGE
import KeyboardWaiterCore
import KeyboardWaiterPet
#endif

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

do {
    let controller = try AppController()

    // ——— 可插拔模块装配。这里是整个工程里唯一同时认识 Core 和各模块的地方。———
    let pet = PetFeature(statsStore: controller.statsStore)
    controller.register(feature: pet)
    DispatchQueue.main.async { pet.restoreWindowIfNeeded() }
    // ————————————————————————————————————————————————————————————

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
