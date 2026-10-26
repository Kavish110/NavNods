import Foundation
import simd

/// Captures the neutral head pose and slowly re-centres it during idle to absorb posture drift (FR2).
nonisolated struct Calibration {
    private(set) var neutral: AttitudeQuaternion

    /// Angular speed must stay under this to count as "idle" for drift recentring.
    var idleAngularSpeedThreshold: Double = 5.0 // deg/s
    /// Pose must stay within this many degrees of neutral to count as idle.
    var idleDistanceThreshold: Double = 6.0 // degrees
    /// How long the idle condition must hold before recentring begins.
    var idleDuration: TimeInterval = 3.0
    /// Fraction of the remaining distance to neutral absorbed per second once recentring is active.
    var recentreRate: Double = 0.3

    private var idleSince: TimeInterval?
    private var lastTimestamp: TimeInterval?

    init(neutral: AttitudeQuaternion = AttitudeQuaternion(x: 0, y: 0, z: 0, w: 1)) {
        self.neutral = neutral
    }

    mutating func calibrate(to attitude: AttitudeQuaternion) {
        neutral = attitude
        idleSince = nil
    }

    /// Call once per motion sample. Returns the relative pose against the current neutral,
    /// and eases `neutral` toward `attitude` while the head has been still for `idleDuration`.
    mutating func process(attitude: AttitudeQuaternion, rotationRateMagnitudeDegPerSec: Double, timestamp: TimeInterval) -> (pitch: Double, yaw: Double, roll: Double) {
        let dt = lastTimestamp.map { max(timestamp - $0, 0) } ?? 0
        lastTimestamp = timestamp

        let relative = RelativePoseMath.relativeEulerDegrees(attitude: attitude, neutral: neutral)
        let distance = sqrt(relative.pitch * relative.pitch + relative.yaw * relative.yaw + relative.roll * relative.roll)

        let isIdle = rotationRateMagnitudeDegPerSec < idleAngularSpeedThreshold && distance < idleDistanceThreshold
        guard isIdle else {
            idleSince = nil
            return relative
        }

        if idleSince == nil {
            idleSince = timestamp
        }
        guard let since = idleSince, timestamp - since >= idleDuration else {
            return relative
        }

        // Ease neutral toward the current attitude via spherical interpolation, scaled by actual
        // elapsed time (never a fixed sample-rate assumption — the AirPods stream rate varies).
        let step = min(1.0, recentreRate * dt)
        neutral = AttitudeQuaternion(simd: simd_slerp(neutral.simd, attitude.simd, step))
        return RelativePoseMath.relativeEulerDegrees(attitude: attitude, neutral: neutral)
    }
}

nonisolated extension AttitudeQuaternion {
    init(simd q: simd_quatd) {
        self.init(x: q.vector.x, y: q.vector.y, z: q.vector.z, w: q.vector.w)
    }
}
