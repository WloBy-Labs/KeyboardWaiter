import CoreGraphics
import Foundation

public enum PointerActivity: String, CaseIterable {
    case leftClick = "pd_left_click"
    case rightClick = "pd_right_click"
    case otherClick = "pd_other_click"
    case scrollUp = "pd_scroll_up"
    case scrollDown = "pd_scroll_down"

    static let prefix = "pd_"

    var activityID: String {
        rawValue
    }

    var displayName: String {
        AppLocalizer.pointerActivityName(self)
    }

    static func from(eventType: CGEventType, event: CGEvent) -> PointerActivity? {
        switch eventType {
        case .leftMouseDown:
            return .leftClick
        case .rightMouseDown:
            return .rightClick
        case .otherMouseDown:
            return .otherClick
        case .scrollWheel:
            return scrollActivity(for: event)
        default:
            return nil
        }
    }

    private static func scrollActivity(for event: CGEvent) -> PointerActivity? {
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        guard momentumPhase == 0 else {
            return nil
        }

        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        if scrollPhase != 0 && scrollPhase != 1 {
            return nil
        }

        var delta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        if delta == 0 {
            delta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        }

        if delta > 0 {
            return .scrollUp
        }

        if delta < 0 {
            return .scrollDown
        }

        return nil
    }
}
