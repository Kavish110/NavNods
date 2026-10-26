import CoreGraphics
import Foundation
import OSLog

@MainActor
protocol ActionExecuting: AnyObject {
    func perform(_ action: Action)
}

/// Main-actor-owned CGEvent dispatcher. Requires Accessibility trust and ENABLE_APP_SANDBOX=NO — both
/// incompatible with the Mac App Store sandbox, per the PRD's distribution section.
@MainActor
final class ActionEngine: ActionExecuting {
    private let logger = Logger(subsystem: "com.nodnav.NodNav", category: "actions")
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    /// Sub-pixel scroll carried between samples. Without it, slow scrolling at high sample rates
    /// rounds to 0 px every sample (40 px/s at 100 Hz is 0.4 px) and nothing moves at all.
    private var scrollRemainder: Double = 0

    private static let leftArrowKeyCode: CGKeyCode = 123
    private static let rightArrowKeyCode: CGKeyCode = 124
    private static let leftBracketKeyCode: CGKeyCode = 33
    private static let rightBracketKeyCode: CGKeyCode = 30

    func perform(_ action: Action) {
        guard AccessibilityPermission.isTrusted else {
            logger.warning("Accessibility permission missing; dropping action")
            return
        }

        switch action {
        case .scroll(let dy):
            postScroll(dy: dy)
        case .previousDesktop:
            postControlArrow(keyCode: Self.leftArrowKeyCode)
        case .nextDesktop:
            postControlArrow(keyCode: Self.rightArrowKeyCode)
        case .browserBack:
            postKey(keyCode: Self.leftBracketKeyCode, flags: .maskCommand)
        case .browserForward:
            postKey(keyCode: Self.rightBracketKeyCode, flags: .maskCommand)
        }
    }

    /// `dy` follows `Action.scroll`'s convention: positive scrolls down (toward the end of the page).
    /// Quartz scroll wheel events use the opposite sign (positive wheel1 scrolls up), so the
    /// delta is negated when posting.
    private func postScroll(dy: Double) {
        // Drop leftover fraction when direction flips so a reversal responds immediately.
        if scrollRemainder != 0, (scrollRemainder > 0) != (dy > 0) {
            scrollRemainder = 0
        }
        let total = scrollRemainder + dy
        let whole = total.rounded(.towardZero)
        scrollRemainder = total - whole
        guard whole != 0 else { return }

        guard let event = CGEvent(
            scrollWheelEvent2Source: eventSource,
            units: .pixel,
            wheelCount: 1,
            wheel1: Int32(-whole),
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func postControlArrow(keyCode: CGKeyCode) {
        postKey(keyCode: keyCode, flags: .maskControl)
    }

    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard
            let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
        else { return }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
