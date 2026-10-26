import Foundation
import Observation

enum PauseReason: Sendable {
    case manual
    case airPodsDisconnected
}

/// Main-actor-owned global pause state (FR9); callbacks hop here before mutation.
@MainActor
@Observable
final class PauseController {
    private(set) var manualPause = false
    private(set) var automaticPauseReason: PauseReason?

    var isPaused: Bool { manualPause || automaticPauseReason != nil }

    func pause() {
        manualPause = true
    }

    func resume() {
        manualPause = false
        automaticPauseReason = nil
    }

    func toggle() {
        manualPause ? resume() : pause()
    }

    func setAirPodsConnected(_ connected: Bool) {
        automaticPauseReason = connected ? nil : .airPodsDisconnected
    }
}
