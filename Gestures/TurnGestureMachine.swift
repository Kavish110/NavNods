import Foundation

nonisolated final class TurnGestureMachine: GestureStateMachine {
    let kind: GestureKind
    private(set) var phase: GesturePhase = .idle
    let angleThreshold: Double
    let neutralThreshold: Double
    let returnWindow: TimeInterval
    private var peakAt: TimeInterval?
    private var peakMagnitude: Double = 0
    private var refractory: RefractoryTimer

    init(direction: Direction, thresholds: GestureThresholds = GestureThresholds()) {
        kind = direction == .left ? .turnLeft : .turnRight
        angleThreshold = thresholds.turnAngle
        neutralThreshold = thresholds.turnNeutralAngle
        returnWindow = thresholds.turnReturnWindow
        refractory = RefractoryTimer(duration: thresholds.refractoryDuration)
    }
    enum Direction { case left, right }

    func update(pose: FilteredPose) -> GestureEvent? {
        guard !refractory.isActive(at: pose.timestamp) else { phase = .refractory; return nil }
        let signedYaw = kind == .turnLeft ? -pose.yaw : pose.yaw
        if peakAt == nil {
            guard signedYaw >= angleThreshold else { phase = .idle; return nil }
            peakAt = pose.timestamp
            peakMagnitude = signedYaw
            phase = .peak
            return nil
        }
        guard let peakAt else { return nil }
        peakMagnitude = max(peakMagnitude, signedYaw)
        guard pose.timestamp - peakAt <= returnWindow else { self.peakAt = nil; phase = .idle; return nil }
        guard abs(pose.yaw) <= neutralThreshold else { phase = .returning; return nil }
        let confidence = min(1, peakMagnitude / (angleThreshold * 1.5))
        self.peakAt = nil
        refractory.markFired(at: pose.timestamp)
        phase = .confirmed
        return GestureEvent(kind: kind, confidence: confidence, timestamp: pose.timestamp)
    }
}
