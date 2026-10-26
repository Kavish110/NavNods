import Foundation
import Observation

enum MotionSourceKind: Sendable, Equatable {
    case liveAirPods
    case simulatedLean
    case simulatedScroll

    /// Simulated sources drive the pose display and gesture pipeline but never post real
    /// keyboard or scroll events: a looping trace would otherwise switch desktops or scroll the
    /// user's frontmost app every few seconds.
    var isSimulated: Bool { self != .liveAirPods }
}

/// A motion sample tagged with where it came from, so a sample still buffered from a simulated
/// source can never trigger a real action after the user switches to live AirPods.
nonisolated struct SourcedSample: Sendable {
    var sample: MotionSample
    var sourceID: UUID
    var isSimulated: Bool
}

/// Main-actor-isolated composition root for the motion pipeline. Owns which MotionSource is
/// active and exposes live pose + last-action state for the menu bar UI. Heavy pipeline work
/// (pose filtering, gesture recognition) happens inside the `GesturePipeline` actor, off the
/// main actor; this class only applies the results.
///
/// Samples flow through one AsyncStream with a single consumer, so they reach the pipeline in
/// the order the source produced them. (Spawning a Task per sample gives no ordering guarantee.)
@MainActor
@Observable
final class MotionPipelineCoordinator {
    private(set) var pose = FilteredPose(pitch: 0, yaw: 0, roll: 0, timestamp: 0)
    private(set) var lastActionDescription = "–"
    private(set) var trackingStatusDescription = "Starting…"

    var sourceKind: MotionSourceKind = .liveAirPods {
        didSet {
            guard oldValue != sourceKind else { return }
            switchSource()
        }
    }

    /// How exaggerated head movement appears to the gesture pipeline and the motion monitor
    /// window; 1.0 passes the filtered pose through unchanged.
    var sensitivity: Double = 1.0 {
        didSet {
            guard oldValue != sensitivity else { return }
            let value = sensitivity
            Task { await pipeline.setSensitivity(value) }
        }
    }

    private nonisolated let pipeline: GesturePipeline
    private let router: ActionRouter
    private let pauseController: PauseController
    private var currentSource: MotionSource?
    private var currentSourceID = UUID()

    private let sampleStream: AsyncStream<SourcedSample>
    private nonisolated let sampleContinuation: AsyncStream<SourcedSample>.Continuation
    private var consumerTask: Task<Void, Never>?

    init(router: ActionRouter, pauseController: PauseController, thresholds: GestureThresholds = GestureThresholds()) {
        self.router = router
        self.pauseController = pauseController
        self.pipeline = GesturePipeline(thresholds: thresholds)
        // Keep only the newest samples if the consumer ever falls behind; stale motion is useless.
        let (stream, continuation) = AsyncStream.makeStream(of: SourcedSample.self, bufferingPolicy: .bufferingNewest(32))
        self.sampleStream = stream
        self.sampleContinuation = continuation
    }

    func start() {
        if consumerTask == nil {
            let stream = sampleStream
            let pipeline = pipeline
            consumerTask = Task { [weak self] in
                var processedSourceID: UUID?
                for await item in stream {
                    if processedSourceID != item.sourceID {
                        await pipeline.prepareForNewSource()
                        processedSourceID = item.sourceID
                    }
                    let output = await pipeline.process(item.sample)
                    self?.apply(output, sourceID: item.sourceID, isSimulated: item.isSimulated)
                }
            }
        }
        switchSource()
    }

    func recalibrate() {
        Task { await pipeline.recalibrate() }
    }

    private func switchSource() {
        if let old = currentSource {
            // Detach first so the old source's final callbacks (e.g. "disconnected" on stop)
            // can't pause the app or feed samples after the new source takes over.
            old.onSample = nil
            old.onConnectionChange = nil
            old.stop()
        }

        let newSourceID = UUID()
        currentSourceID = newSourceID
        trackingStatusDescription = sourceKind.isSimulated ? "Previewing simulated motion" : "Waiting for AirPods motion…"

        let newSource: MotionSource
        switch sourceKind {
        case .simulatedLean:
            newSource = SimulatedMotionSource.leanLeftTrace()
        case .simulatedScroll:
            newSource = SimulatedMotionSource.tiltDownTrace()
        case .liveAirPods:
            newSource = HeadphoneMotionSource()
        }

        newSource.onConnectionChange = { [weak self] connected in
            Task { @MainActor in
                guard let self, self.currentSourceID == newSourceID else { return }
                self.pauseController.setAirPodsConnected(connected)
                self.trackingStatusDescription = connected ? "Tracking AirPods" : "Waiting for compatible AirPods…"
            }
        }
        let continuation = sampleContinuation
        let isSimulated = sourceKind.isSimulated
        newSource.onSample = { sample in
            continuation.yield(SourcedSample(sample: sample, sourceID: newSourceID, isSimulated: isSimulated))
        }
        currentSource = newSource
        newSource.start()
    }

    private func apply(_ output: PipelineOutput, sourceID: UUID, isSimulated: Bool) {
        guard sourceID == currentSourceID else { return }
        pose = output.pose
        trackingStatusDescription = isSimulated ? "Previewing simulated motion" : "Tracking AirPods"
        guard let action = output.action else { return }
        if !isSimulated {
            router.perform(action)
        }
        if let label = output.actionLabel {
            lastActionDescription = isSimulated ? "\(label) (preview)" : label
        }
    }
}
