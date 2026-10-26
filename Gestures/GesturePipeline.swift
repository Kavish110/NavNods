import Foundation

struct PipelineOutput: Sendable {
    var pose: FilteredPose
    var action: Action?
    var actionLabel: String?
}

/// Owns everything that runs off the main actor: pose processing + gesture recognition
/// (pipeline steps 1-7). An actor rather than a plain class so `process(_:)` (called from the
/// motion source's callback) and `recalibrate()` (called from a UI button tap) can never race —
/// the PRD's "motion runs on its own serial queue" requirement, expressed with Swift concurrency
/// instead of a raw DispatchQueue.
actor GesturePipeline {
    private let poseProcessor: PoseProcessor
    private let leanLeft: LeanDesktopGestureMachine
    private let leanRight: LeanDesktopGestureMachine
    private let turnLeft: TurnGestureMachine
    private let turnRight: TurnGestureMachine
    private let scrollController: ScrollModeController
    private let arbiter = GestureArbiter()

    private var lastTimestamp: TimeInterval?
    private var needsInitialCalibration = true
    private var lastAttitude = AttitudeQuaternion(x: 0, y: 0, z: 0, w: 1)

    /// Multiplies the filtered pose before gesture recognition, scrolling and display — turning
    /// the sensitivity slider into "how far a given physical head movement appears to travel".
    private var sensitivity: Double = 1.0

    init(thresholds: GestureThresholds = GestureThresholds()) {
        poseProcessor = PoseProcessor(bodyMotionAccelerationThreshold: thresholds.bodyMotionAccelerationThreshold)
        leanLeft = LeanDesktopGestureMachine(direction: .left, thresholds: thresholds)
        leanRight = LeanDesktopGestureMachine(direction: .right, thresholds: thresholds)
        turnLeft = TurnGestureMachine(direction: .left, thresholds: thresholds)
        turnRight = TurnGestureMachine(direction: .right, thresholds: thresholds)
        scrollController = ScrollModeController(thresholds: thresholds)
    }

    func recalibrate() {
        poseProcessor.recalibrate(to: lastAttitude)
    }

    func prepareForNewSource() {
        lastTimestamp = nil
        needsInitialCalibration = true
    }

    func setSensitivity(_ value: Double) {
        sensitivity = value
    }

    func process(_ sample: MotionSample) -> PipelineOutput {
        if needsInitialCalibration {
            poseProcessor.recalibrate(to: sample.attitude)
            needsInitialCalibration = false
        }
        lastAttitude = sample.attitude
        let dt = lastTimestamp.map { max(sample.timestamp - $0, 1.0 / 1000.0) } ?? (1.0 / 60.0)
        lastTimestamp = sample.timestamp

        let (rawPose, gated) = poseProcessor.ingest(sample)
        let pose = FilteredPose(
            pitch: rawPose.pitch * sensitivity,
            yaw: rawPose.yaw * sensitivity,
            roll: rawPose.roll * sensitivity,
            timestamp: rawPose.timestamp
        )

        var winner: GestureEvent?
        if !gated {
            if let event = leanLeft.update(pose: pose) {
                winner = arbiter.submit(event)
            }
            if winner == nil, let event = leanRight.update(pose: pose) {
                winner = arbiter.submit(event)
            }
            if winner == nil, let event = turnLeft.update(pose: pose) { winner = arbiter.submit(event) }
            if winner == nil, let event = turnRight.update(pose: pose) { winner = arbiter.submit(event) }
            if winner == nil, let flushed = arbiter.flush(upTo: pose.timestamp) {
                winner = flushed
            }
        }

        if let winner {
            switch winner.kind {
            case .leanLeft:
                return PipelineOutput(pose: pose, action: .previousDesktop, actionLabel: "← Desktop")
            case .leanRight:
                return PipelineOutput(pose: pose, action: .nextDesktop, actionLabel: "Desktop →")
            case .turnLeft:
                return PipelineOutput(pose: pose, action: .browserBack, actionLabel: "← Back")
            case .turnRight:
                return PipelineOutput(pose: pose, action: .browserForward, actionLabel: "Forward →")
            case .nod, .shake:
                break
            }
        }

        if let dy = scrollController.update(pose: pose, dt: dt) {
            return PipelineOutput(pose: pose, action: .scroll(dy: dy), actionLabel: dy > 0 ? "Scroll ↓" : "Scroll ↑")
        }

        return PipelineOutput(pose: pose, action: nil, actionLabel: nil)
    }
}
