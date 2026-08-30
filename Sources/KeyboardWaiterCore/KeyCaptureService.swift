import CoreGraphics
import Foundation

public final class KeyCaptureService {
    public var onKeyCapture: ((KeyDescriptor) -> Void)?
    public var onPointerCapture: ((PointerActivity) -> Void)?
    public var onPointerTravel: ((Int) -> Void)?
    public var onTapFailure: (() -> Void)?

    public private(set) var isRunning = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressedModifierKeyCodes = Set<UInt16>()
    private var motionCoalescer = PointerMotionCoalescer(idleGap: PointerSettings.motionIdleGap)
    private var dragTracker = PointerDragTracker()
    private var travelAccumulator = PointerTravelAccumulator()

    public init() {}

    /// 设置界面改动后立即生效，不需要重启监听。
    public func updateMotionIdleGap(_ idleGap: TimeInterval) {
        motionCoalescer.idleGap = idleGap
    }

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
        motionCoalescer.reset()
        travelAccumulator.reset()
        dragTracker.reset()
        isRunning = false
    }

    private func createEventTap() -> CFMachPort? {
        let keyDownMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let flagsChangedMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let leftMouseDownMask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        let rightMouseDownMask = CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
        let otherMouseDownMask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
        let scrollWheelMask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let mouseMovedMask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
        let leftDragMask = CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
        let rightDragMask = CGEventMask(1 << CGEventType.rightMouseDragged.rawValue)
        let otherDragMask = CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)
        let leftMouseUpMask = CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
        let rightMouseUpMask = CGEventMask(1 << CGEventType.rightMouseUp.rawValue)
        let otherMouseUpMask = CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
        let callbackPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: keyDownMask | flagsChangedMask | leftMouseDownMask | rightMouseDownMask
                | otherMouseDownMask | scrollWheelMask | mouseMovedMask
                | leftDragMask | rightDragMask | otherDragMask
                | leftMouseUpMask | rightMouseUpMask | otherMouseUpMask,
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

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            dragTracker.pressBegan(button: event.getIntegerValueField(.mouseEventButtonNumber))
            guard let activity = PointerActivity.from(eventType: eventType, event: event) else { return }
            publish(pointerActivity: activity)

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            dragTracker.pressEnded(button: event.getIntegerValueField(.mouseEventButtonNumber))

        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            accumulateTravel(from: event)
            guard dragTracker.shouldCountDrag(button: event.getIntegerValueField(.mouseEventButtonNumber)) else { return }
            publish(pointerActivity: .drag)

        case .mouseMoved:
            accumulateTravel(from: event)
            guard motionCoalescer.shouldCount(.move, at: ProcessInfo.processInfo.systemUptime) else { return }
            publish(pointerActivity: .move)

        case .scrollWheel:
            guard let activity = PointerActivity.from(eventType: eventType, event: event) else { return }
            publish(pointerActivity: activity)

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // 事件流断过，按下/松开可能丢了，状态重新来过。
            motionCoalescer.reset()
            dragTracker.reset()

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

    private func accumulateTravel(from event: CGEvent) {
        let deltaX = Double(event.getIntegerValueField(.mouseEventDeltaX))
        let deltaY = Double(event.getIntegerValueField(.mouseEventDeltaY))
        let units = travelAccumulator.add(deltaX: deltaX, deltaY: deltaY)
        guard units > 0 else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onPointerTravel?(units)
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
