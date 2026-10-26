import CoreMotion
import Foundation

/// Thread-safe Core Motion service. Streaming flags are lock-protected; samples arrive on its queue.
///
/// Connection state is reported from what actually happens, not from callbacks alone:
/// - "connected" is reported on the first motion sample after (re)starting, so AirPods that were
///   already connected before `start()` still unpause the app (didConnect may never fire for them).
/// - "disconnected" is reported when updates can't start, on a stream error, or on didDisconnect.
/// - When AirPods (re)connect, updates are (re)started, so the app recovers if the buds weren't
///   available at launch, per the PRD's reliability requirement.
/// - A 1s retry loop backs up didConnect: that delegate callback only fires on a *new* Bluetooth
///   connection, so it never helps when motion is momentarily unavailable for buds that were
///   already connected before start() (e.g. authorization still resolving).
nonisolated final class HeadphoneMotionSource: NSObject, MotionSource, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    var onSample: (@Sendable (MotionSample) -> Void)?
    var onConnectionChange: (@Sendable (Bool) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.nodnav.motion.headphone"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInteractive
        return q
    }()

    private let lock = NSLock()
    /// true between start() and stop(): the app wants motion whenever it becomes available.
    private var wantsUpdates = false
    /// true while startDeviceMotionUpdates is active on the manager.
    private var isStreaming = false
    /// true once "connected" has been reported for the current streaming session.
    private var hasReportedConnected = false

    override init() {
        super.init()
        manager.delegate = self
    }

    var isAvailable: Bool { CMHeadphoneMotionManager.authorizationStatus() != .denied && manager.isDeviceMotionAvailable }

    func start() {
        lock.withLock { wantsUpdates = true }
        manager.startConnectionStatusUpdates()
        startUpdatesIfPossible()
    }

    func stop() {
        lock.withLock {
            wantsUpdates = false
            isStreaming = false
            hasReportedConnected = false
        }
        manager.stopDeviceMotionUpdates()
        manager.stopConnectionStatusUpdates()
    }

    nonisolated private enum StartDecision {
        case start
        case alreadyStreaming
        case notWanted
        case unavailable
    }

    private func startUpdatesIfPossible() {
        let decision: StartDecision = lock.withLock {
            guard wantsUpdates else { return .notWanted }
            guard !isStreaming else { return .alreadyStreaming }
            guard isAvailable else { return .unavailable }
            isStreaming = true
            hasReportedConnected = false
            return .start
        }

        switch decision {
        case .notWanted, .alreadyStreaming:
            return
        case .unavailable:
            // Pause the app and keep retrying: headphoneMotionManagerDidConnect only fires on a
            // *new* Bluetooth connection, so buds that were already connected before start() (or
            // motion that becomes available moments later, e.g. authorization still resolving)
            // would otherwise never get another chance to start streaming.
            onConnectionChange?(false)
            scheduleRetry()
        case .start:
            manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
                guard let self else { return }
                if error != nil {
                    self.handleStreamError()
                    return
                }
                guard let motion else { return }
                self.reportConnectedIfNeeded()
                self.onSample?(Self.sample(from: motion))
            }
        }
    }

    /// Re-checks availability shortly after an `.unavailable` result. Self-terminating: once
    /// `stop()` has been called, the next `startUpdatesIfPossible()` sees `wantsUpdates == false`
    /// and returns without scheduling another retry.
    private func scheduleRetry() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startUpdatesIfPossible()
        }
    }

    private func reportConnectedIfNeeded() {
        let shouldReport: Bool = lock.withLock {
            guard wantsUpdates, isStreaming, !hasReportedConnected else { return false }
            hasReportedConnected = true
            return true
        }
        if shouldReport {
            onConnectionChange?(true)
        }
    }

    private func handleStreamError() {
        let wasStreaming: Bool = lock.withLock {
            let was = isStreaming
            isStreaming = false
            hasReportedConnected = false
            return was
        }
        guard wasStreaming else { return }
        manager.stopDeviceMotionUpdates()
        onConnectionChange?(false)
        scheduleRetry()
    }

    private static func sample(from motion: CMDeviceMotion) -> MotionSample {
        let q = motion.attitude.quaternion
        let degreesPerSecond = 180.0 / .pi
        return MotionSample(
            timestamp: motion.timestamp,
            attitude: AttitudeQuaternion(x: q.x, y: q.y, z: q.z, w: q.w),
            rotationRate: (
                motion.rotationRate.x * degreesPerSecond,
                motion.rotationRate.y * degreesPerSecond,
                motion.rotationRate.z * degreesPerSecond
            ),
            userAcceleration: (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z)
        )
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        // Restart cleanly so a session that never started (buds absent at launch) or one that
        // went stale while disconnected begins streaming again. "Connected" is reported on the
        // first sample that arrives.
        let restart: Bool = lock.withLock {
            guard wantsUpdates else { return false }
            isStreaming = false
            hasReportedConnected = false
            return true
        }
        guard restart else { return }
        manager.stopDeviceMotionUpdates()
        startUpdatesIfPossible()
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        lock.withLock {
            isStreaming = false
            hasReportedConnected = false
        }
        manager.stopDeviceMotionUpdates()
        onConnectionChange?(false)
    }
}
