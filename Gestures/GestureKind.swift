import Foundation

/// Only the gestures implemented in this slice. The other six from the PRD's vocabulary
/// (turn flick left/right, nod, shake) are deferred — they need frontmost-app detection and
/// call-state detection respectively, neither of which exists yet. Add cases here as those
/// land, rather than stubbing them out now.
nonisolated enum GestureKind: Sendable, Equatable {
    case turnLeft, turnRight, leanLeft, leanRight, nod, shake
}
