import CoreGraphics
import Foundation

public enum PointerActivity: String, CaseIterable {
    case leftClick = "pd_left_click"
    case rightClick = "pd_right_click"
    case otherClick = "pd_other_click"
    case move = "pd_move"
    case drag = "pd_drag"
    case scrollUp = "pd_scroll_up"
    case scrollDown = "pd_scroll_down"
    case scrollLeft = "pd_scroll_left"
    case scrollRight = "pd_scroll_right"

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
        case .mouseMoved:
            return .move
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return .drag
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

        let vertical = delta(
            of: event,
            pointField: .scrollWheelEventPointDeltaAxis1,
            lineField: .scrollWheelEventDeltaAxis1
        )
        let horizontal = delta(
            of: event,
            pointField: .scrollWheelEventPointDeltaAxis2,
            lineField: .scrollWheelEventDeltaAxis2
        )

        if abs(vertical) >= abs(horizontal) && vertical != 0 {
            return vertical > 0 ? .scrollUp : .scrollDown
        }

        if horizontal != 0 {
            return horizontal > 0 ? .scrollLeft : .scrollRight
        }

        return nil
    }

    private static func delta(
        of event: CGEvent,
        pointField: CGEventField,
        lineField: CGEventField
    ) -> Int64 {
        let pointDelta = event.getIntegerValueField(pointField)
        if pointDelta != 0 {
            return pointDelta
        }
        return event.getIntegerValueField(lineField)
    }
}
