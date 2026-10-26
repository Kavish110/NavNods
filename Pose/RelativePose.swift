import Foundation
import simd

/// Pitch, yaw and roll in degrees, relative to the calibrated neutral pose.
nonisolated struct FilteredPose: Sendable {
    var pitch: Double
    var yaw: Double
    var roll: Double
    var timestamp: TimeInterval
}

/// Attitude as a unit quaternion (w, x, y, z), matching CMQuaternion's layout.
nonisolated struct AttitudeQuaternion: Sendable {
    var x: Double
    var y: Double
    var z: Double
    var w: Double

    var simd: simd_quatd { simd_quatd(ix: x, iy: y, iz: z, r: w) }
}

nonisolated enum RelativePoseMath {
    /// Rotates `attitude` into the neutral frame (relativeAttitude = neutral⁻¹ * attitude), then
    /// converts to Euler angles in degrees. Working in quaternions here — rather than subtracting
    /// Euler angles directly — avoids gimbal-lock artifacts when the head is turned at large angles.
    static func relativeEulerDegrees(attitude: AttitudeQuaternion, neutral: AttitudeQuaternion) -> (pitch: Double, yaw: Double, roll: Double) {
        let relative = neutral.simd.inverse * attitude.simd
        return eulerDegrees(from: relative)
    }

    /// Euler extraction matching CoreMotion's axis naming (CMAttitude): pitch = rotation about X
    /// (nodding), roll = rotation about Y (tilting toward a shoulder), yaw = rotation about Z
    /// (turning). An earlier version labelled X as roll and Y as pitch, which the simulator could
    /// not catch because it built its quaternions with the same swapped labels; on real AirPods
    /// that made nodding switch desktops and shoulder tilts scroll.
    static func eulerDegrees(from q: simd_quatd) -> (pitch: Double, yaw: Double, roll: Double) {
        let x = q.vector.x, y = q.vector.y, z = q.vector.z, w = q.vector.w

        // Pitch (rotation about X)
        let sinpCosr = 2 * (w * x + y * z)
        let cospCosr = 1 - 2 * (x * x + y * y)
        let pitch = atan2(sinpCosr, cospCosr)

        // Roll (rotation about Y)
        let sinr = 2 * (w * y - z * x)
        let roll: Double
        if abs(sinr) >= 1 {
            roll = copysign(.pi / 2, sinr)
        } else {
            roll = asin(sinr)
        }

        // Yaw (rotation about Z)
        let sinyCosp = 2 * (w * z + x * y)
        let cosyCosp = 1 - 2 * (y * y + z * z)
        let yaw = atan2(sinyCosp, cosyCosp)

        return (pitch: pitch * 180 / .pi, yaw: yaw * 180 / .pi, roll: roll * 180 / .pi)
    }

    /// Inverse of `eulerDegrees`: builds the quaternion that decodes back to the given pitch/yaw/roll,
    /// using the matching composition order (q = Rz(yaw) * Ry(roll) * Rx(pitch)). Used by the
    /// simulated motion source and by trace-replay code to script gestures in degrees.
    static func quaternion(pitch: Double, yaw: Double, roll: Double) -> AttitudeQuaternion {
        let rx = simd_quatd(angle: pitch * .pi / 180, axis: simd_double3(1, 0, 0))
        let ry = simd_quatd(angle: roll * .pi / 180, axis: simd_double3(0, 1, 0))
        let rz = simd_quatd(angle: yaw * .pi / 180, axis: simd_double3(0, 0, 1))
        return AttitudeQuaternion(simd: rz * ry * rx)
    }
}
