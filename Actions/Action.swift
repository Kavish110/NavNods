import Foundation

/// What the Action Router can dispatch. Browser back/forward and call answer/decline are in the
/// PRD's action map but need frontmost-app detection and call adapters respectively — neither
/// exists yet, so they're intentionally not cases here until that groundwork lands.
nonisolated enum Action: Sendable, Equatable {
    case scroll(dy: Double)
    case previousDesktop
    case nextDesktop
    case browserBack
    case browserForward
}
