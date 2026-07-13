import CoreGraphics
import Foundation

public final class KeyCaptureService {
    public var onKeyCapture: ((KeyDescriptor) -> Void)?
    public var onPointerCapture: ((PointerActivity) -> Void)?
    public var onTapFailure: (() -> Void)?

    public private(set) var isRunning = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressedModifierKeyCodes = Set<UInt16>()

    public init() {}

    deinit {
        stop()
    }

    @discardableResult
    public func start() -> Bool {
        guard !isRunning else { return true }
        guard let tap = createEventTap() else {
            onTapFailure?()
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        isRunning = true
        return true
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        pressedModifierKeyCodes.removeAll()
        isRunning = false
    }

    private func createEventTap() -> CFMachPort? {
        let keyDownMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let flagsChangedMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let leftMouseDownMask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        let rightMouseDownMask = CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
        let otherMouseDownMask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
        let scrollWheelMask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callbackPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: keyDownMask | flagsChangedMask | leftMouseDownMask | rightMouseDownMask | otherMouseDownMask | scrollWheelMask,
            callback: Self.callback,
            userInfo: callbackPointer
        )
    }

    private func handle(eventType: CGEventType, event: CGEvent) {
        switch eventType {
        case .keyDown:
            let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            guard !isAutoRepeat else { return }
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            publish(keyCode: keyCode)

        case .flagsChanged:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            handleModifierChange(keyCode: keyCode, flags: event.flags)

        case .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel:
            guard let activity = PointerActivity.from(eventType: eventType, event: event) else { return }
            publish(pointerActivity: activity)

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            } else {
                onTapFailure?()
            }

        default:
            break
        }
    }
    private func publish(keyCode: CGKeyCode) {
        let descriptor = KeyTranslator.descriptor(for: keyCode)
        DispatchQueue.main.async { [weak self] in
            self?.onKeyCapture?(descriptor)
        }
    }

    private func publish(pointerActivity: PointerActivity) {
        DispatchQueue.main.async { [weak self] in
            self?.onPointerCapture?(pointerActivity)
        }
    }

    private func handleModifierChange(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let modifierFlag = Self.modifierFlag(for: keyCode) else { return }

        let rawKeyCode = UInt16(keyCode)
        let wasPressed = pressedModifierKeyCodes.contains(rawKeyCode)
        let isStillActive = flags.contains(modifierFlag)

        switch (wasPressed, isStillActive) {
        case (false, true):
            pressedModifierKeyCodes.insert(rawKeyCode)
            publish(keyCode: keyCode)

        case (true, false), (true, true):
            pressedModifierKeyCodes.remove(rawKeyCode)

        case (false, false):
            break
        }
    }

    private static func modifierFlag(for keyCode: CGKeyCode) -> CGEventFlags? {
        switch keyCode {
        case 54, 55:
            return .maskCommand
        case 56, 60:
            return .maskShift
        case 57:
            return .maskAlphaShift
        case 58, 61:
            return .maskAlternate
        case 59, 62:
            return .maskControl
        case 63:
            return .maskSecondaryFn
        default:
            return nil
        }
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<KeyCaptureService>.fromOpaque(userInfo).takeUnretainedValue()
        service.handle(eventType: type, event: event)
        return Unmanaged.passUnretained(event)
    }
}
