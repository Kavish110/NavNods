import Foundation

/// Tilt up/down -> continuous scroll. Deliberately NOT a GestureStateMachine conformer: the PRD
/// treats scroll as a continuous model (dead zone + velocity curve), not a discrete onset/confirm
/// gesture, so forcing it into that shape would misrepresent the behavior, not just omit a feature.
nonisolated final class ScrollModeController {
    let deadZoneDegrees: Double
    let maxTiltDegrees: Double
    /// Pixels/sec at the dead zone edge.
    let minSpeed: Double
    /// Pixels/sec at maxTiltDegrees.
    let maxSpeed: Double
    var isEnabled: Bool = true

    init(thresholds: GestureThresholds = GestureThresholds()) {
        deadZoneDegrees = thresholds.scrollDeadZone
        maxTiltDegrees = thresholds.scrollMaximumTilt
        minSpeed = thresholds.scrollMinimumSpeed
        maxSpeed = thresholds.scrollMaximumSpeed
    }

    /// Returns the scroll delta (pixels) to post for this sample, or nil when inside the dead zone
    /// (caller should stop scrolling immediately — within one frame per the PRD).
    func update(pose: FilteredPose, dt: TimeInterval) -> Double? {
        guard isEnabled else { return nil }
        let pitch = pose.pitch
        let magnitude = abs(pitch)
        guard magnitude > deadZoneDegrees else { return nil }

        let span = max(maxTiltDegrees - deadZoneDegrees, 0.001)
        let fraction = min((magnitude - deadZoneDegrees) / span, 1.0)
        let speed = minSpeed + fraction * (maxSpeed - minSpeed)

        // Tilt down (negative pitch, per our convention) scrolls down -> positive pixel delta.
        let direction: Double = pitch < 0 ? 1 : -1
        return direction * speed * dt
    }
}
