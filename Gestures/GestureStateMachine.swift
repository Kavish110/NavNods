import Foundation

/// Pipeline step 6: Idle -> Onset -> Peak -> Return -> Confirmed, with a refractory period after firing.
enum GesturePhase: Sendable, Equatable {
    case idle
    case onset
    case peak
    case returning
    case confirmed
    /// Suppresses re-triggering for `refractoryPeriod` after a Confirmed fire.
    case refractory
}

nonisolated protocol GestureStateMachine: AnyObject {
    var kind: GestureKind { get }
    var phase: GesturePhase { get }

    /// Feed one filtered pose sample. Returns a GestureEvent only on the sample where the
    /// machine transitions into Confirmed.
    func update(pose: FilteredPose) -> GestureEvent?
}

/// Shared refractory-period bookkeeping so individual machines don't reimplement it.
nonisolated struct RefractoryTimer {
    let duration: TimeInterval
    private var firedAt: TimeInterval?

    init(duration: TimeInterval) {
        self.duration = duration
    }

    mutating func markFired(at timestamp: TimeInterval) {
        firedAt = timestamp
    }

    func isActive(at timestamp: TimeInterval) -> Bool {
        guard let firedAt else { return false }
        return timestamp - firedAt < duration
    }
}
