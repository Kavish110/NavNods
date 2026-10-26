import Foundation

/// Lean left/right, held for `holdDuration`, 15°+ past neutral -> previous/next desktop.
/// A lean is a sustained hold rather than a flick, so it only uses Idle -> Onset -> Confirmed ->
/// Refractory of the shared GesturePhase states; Peak/Return don't apply to this gesture shape.
nonisolated final class LeanDesktopGestureMachine: GestureStateMachine {
    let kind: GestureKind
    private(set) var phase: GesturePhase = .idle

    let angleThreshold: Double
    let holdDuration: TimeInterval

    private var onsetAt: TimeInterval?
    private var refractory: RefractoryTimer
    /// Set after a Confirmed fire; stays true until the pose returns below threshold, so one
    /// sustained lean fires exactly once instead of repeating every refractory+hold interval.
    private var waitingForRelease = false

    init(direction: Direction, thresholds: GestureThresholds = GestureThresholds()) {
        self.kind = direction == .left ? .leanLeft : .leanRight
        self.angleThreshold = thresholds.leanAngle
        self.holdDuration = thresholds.leanHoldDuration
        self.refractory = RefractoryTimer(duration: thresholds.refractoryDuration)
    }

    enum Direction {
        case left
        case right
    }

    func update(pose: FilteredPose) -> GestureEvent? {
        let pastThreshold = kind == .leanLeft ? pose.roll <= -angleThreshold : pose.roll >= angleThreshold

        if waitingForRelease {
            if pastThreshold {
                phase = .refractory
            } else {
                waitingForRelease = false
                phase = .idle
            }
            return nil
        }

        guard pastThreshold else {
            phase = .idle
            onsetAt = nil
            return nil
        }

        guard !refractory.isActive(at: pose.timestamp) else {
            phase = .refractory
            return nil
        }

        if onsetAt == nil {
            onsetAt = pose.timestamp
            phase = .onset
            return nil
        }

        guard let onset = onsetAt, pose.timestamp - onset >= holdDuration else {
            phase = .onset
            return nil
        }

        phase = .confirmed
        refractory.markFired(at: pose.timestamp)
        onsetAt = nil
        waitingForRelease = true

        let confidence = min(1.0, abs(pose.roll) / (angleThreshold * 2))
        return GestureEvent(kind: kind, confidence: confidence, timestamp: pose.timestamp)
    }
}
