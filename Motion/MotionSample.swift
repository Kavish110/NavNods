import Foundation

/// A single timestamped reading from the AirPods motion stream (pipeline step 1 — ingest).
nonisolated struct MotionSample: Sendable {
    var timestamp: TimeInterval
    var attitude: AttitudeQuaternion
    /// Degrees per second, per axis.
    var rotationRate: (x: Double, y: Double, z: Double)
    /// In g, per axis — gravity already removed by CoreMotion.
    var userAcceleration: (x: Double, y: Double, z: Double)

    var rotationRateMagnitude: Double {
        sqrt(rotationRate.x * rotationRate.x + rotationRate.y * rotationRate.y + rotationRate.z * rotationRate.z)
    }

    var userAccelerationMagnitude: Double {
        sqrt(userAcceleration.x * userAcceleration.x + userAcceleration.y * userAcceleration.y + userAcceleration.z * userAcceleration.z)
    }
}
