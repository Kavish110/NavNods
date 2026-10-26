import Foundation

/// Abstracts over where motion samples come from — real AirPods or a scripted simulation —
/// so the rest of the pipeline (Pose, Gestures, Actions) never knows the difference.
nonisolated protocol MotionSource: AnyObject {
    /// Called on the source's own serial queue, never the main actor.
    var onSample: (@Sendable (MotionSample) -> Void)? { get set }
    /// true when both buds are connected and streaming motion.
    var onConnectionChange: (@Sendable (Bool) -> Void)? { get set }

    func start()
    func stop()
}
