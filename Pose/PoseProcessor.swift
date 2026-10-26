import Foundation

/// Mutable filter state is owned exclusively by GesturePipeline's actor.
nonisolated final class PoseProcessor {
    private var calibration: Calibration
    private var pitchFilter: OneEuroFilter
    private var yawFilter: OneEuroFilter
    private var rollFilter: OneEuroFilter

    /// Body motion gate (pipeline step 5): above this, discrete gestures are suppressed because the
    /// user is walking, standing up, or making some other gross body movement rather than a deliberate
    /// head gesture.
    var bodyMotionAccelerationThreshold: Double = 0.3 // g

    init(
        neutral: AttitudeQuaternion = AttitudeQuaternion(x: 0, y: 0, z: 0, w: 1),
        minCutoff: Double = 1.0,
        beta: Double = 0.3,
        dCutoff: Double = 1.0,
        bodyMotionAccelerationThreshold: Double = 0.3
    ) {
        self.calibration = Calibration(neutral: neutral)
        self.pitchFilter = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        self.yawFilter = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        self.rollFilter = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        self.bodyMotionAccelerationThreshold = bodyMotionAccelerationThreshold
    }

    func recalibrate(to attitude: AttitudeQuaternion) {
        calibration.calibrate(to: attitude)
        pitchFilter.reset()
        yawFilter.reset()
        rollFilter.reset()
    }

    /// Returns nil when the body motion gate suppresses this sample (caller should still feed
    /// continuous gestures from the raw pose if desired — the gate only governs discrete gestures).
    @discardableResult
    func ingest(_ sample: MotionSample) -> (pose: FilteredPose, bodyMotionGated: Bool) {
        let relative = calibration.process(
            attitude: sample.attitude,
            rotationRateMagnitudeDegPerSec: sample.rotationRateMagnitude,
            timestamp: sample.timestamp
        )

        let pitch = pitchFilter.filter(value: relative.pitch, timestamp: sample.timestamp)
        let yaw = yawFilter.filter(value: relative.yaw, timestamp: sample.timestamp)
        let roll = rollFilter.filter(value: relative.roll, timestamp: sample.timestamp)

        let pose = FilteredPose(pitch: pitch, yaw: yaw, roll: roll, timestamp: sample.timestamp)
        let gated = sample.userAccelerationMagnitude > bodyMotionAccelerationThreshold
        return (pose, gated)
    }
}
