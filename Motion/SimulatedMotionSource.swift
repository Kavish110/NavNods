import Foundation

/// Queue-confined scripted source; timer state is mutated on its private serial queue.
/// This is what makes the pipeline demoable and verifiable without a physical headphone pair, and it
/// doubles as the seed format for the PRD's later trace-library / CI-replay infrastructure.
nonisolated final class SimulatedMotionSource: MotionSource, @unchecked Sendable {
    struct Keyframe {
        var time: TimeInterval
        var pitch: Double
        var yaw: Double
        var roll: Double
    }

    var onSample: (@Sendable (MotionSample) -> Void)?
    var onConnectionChange: (@Sendable (Bool) -> Void)?

    private let keyframes: [Keyframe]
    private let sampleRate: Double
    private let queue = DispatchQueue(label: "com.nodnav.motion.simulated")
    private var timer: DispatchSourceTimer?
    private var elapsed: TimeInterval = 0
    private var loops: Bool

    /// - Parameters:
    ///   - keyframes: must be sorted ascending by `time`. Values are linearly interpolated between frames.
    ///   - sampleRate: samples per second to emit.
    ///   - loops: when true, repeats the trace after the last keyframe's time.
    init(keyframes: [Keyframe], sampleRate: Double = 60, loops: Bool = true) {
        self.keyframes = keyframes
        self.sampleRate = sampleRate
        self.loops = loops
    }

    /// A gentle neutral hold, useful as a default so the menu bar doesn't show a live gesture firing on launch.
    static func neutral(sampleRate: Double = 60) -> SimulatedMotionSource {
        SimulatedMotionSource(keyframes: [Keyframe(time: 0, pitch: 0, yaw: 0, roll: 0)], sampleRate: sampleRate, loops: true)
    }

    /// Lean left, hold past the 300ms/15° threshold, return to neutral — exercises the discrete gesture path.
    static func leanLeftTrace(sampleRate: Double = 60) -> SimulatedMotionSource {
        SimulatedMotionSource(keyframes: [
            Keyframe(time: 0.0, pitch: 0, yaw: 0, roll: 0),
            Keyframe(time: 0.3, pitch: 0, yaw: 0, roll: -20),
            Keyframe(time: 1.0, pitch: 0, yaw: 0, roll: -20),
            Keyframe(time: 1.3, pitch: 0, yaw: 0, roll: 0),
            Keyframe(time: 3.0, pitch: 0, yaw: 0, roll: 0),
        ], sampleRate: sampleRate, loops: true)
    }

    /// Tilt down past the 10° dead zone and hold — exercises the continuous scroll path.
    static func tiltDownTrace(sampleRate: Double = 60) -> SimulatedMotionSource {
        SimulatedMotionSource(keyframes: [
            Keyframe(time: 0.0, pitch: 0, yaw: 0, roll: 0),
            Keyframe(time: 0.5, pitch: -18, yaw: 0, roll: 0),
            Keyframe(time: 2.5, pitch: -18, yaw: 0, roll: 0),
            Keyframe(time: 3.0, pitch: 0, yaw: 0, roll: 0),
            Keyframe(time: 4.0, pitch: 0, yaw: 0, roll: 0),
        ], sampleRate: sampleRate, loops: true)
    }

    func start() {
        onConnectionChange?(true)
        elapsed = 0
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / sampleRate)
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        onConnectionChange?(false)
    }

    private func tick() {
        guard let first = keyframes.first, let last = keyframes.last else { return }
        var t = elapsed
        elapsed += 1.0 / sampleRate
        if loops, last.time > first.time {
            t = t.truncatingRemainder(dividingBy: last.time)
        }

        let pose = interpolate(at: t)
        let sample = MotionSample(
            timestamp: elapsed,
            attitude: RelativePoseMath.quaternion(pitch: pose.pitch, yaw: pose.yaw, roll: pose.roll),
            rotationRate: (0, 0, 0),
            userAcceleration: (0, 0, 0)
        )
        onSample?(sample)
    }

    private func interpolate(at t: TimeInterval) -> (pitch: Double, yaw: Double, roll: Double) {
        guard keyframes.count > 1 else {
            let only = keyframes.first ?? Keyframe(time: 0, pitch: 0, yaw: 0, roll: 0)
            return (only.pitch, only.yaw, only.roll)
        }
        guard let upperIndex = keyframes.firstIndex(where: { $0.time >= t }) else {
            let last = keyframes[keyframes.count - 1]
            return (last.pitch, last.yaw, last.roll)
        }
        guard upperIndex > 0 else {
            let first = keyframes[0]
            return (first.pitch, first.yaw, first.roll)
        }
        let a = keyframes[upperIndex - 1]
        let b = keyframes[upperIndex]
        let span = b.time - a.time
        let fraction = span > 0 ? (t - a.time) / span : 0
        return (
            a.pitch + (b.pitch - a.pitch) * fraction,
            a.yaw + (b.yaw - a.yaw) * fraction,
            a.roll + (b.roll - a.roll) * fraction
        )
    }
}
