import Foundation
import Observation

nonisolated struct GestureThresholds: Codable, Equatable, Sendable {
    var leanAngle = 15.0
    var leanHoldDuration = 0.3
    var turnAngle = 20.0
    var turnNeutralAngle = 7.0
    var turnReturnWindow = 0.6
    var refractoryDuration = 0.7
    var scrollDeadZone = 10.0
    var scrollMaximumTilt = 35.0
    var scrollMinimumSpeed = 40.0
    var scrollMaximumSpeed = 1_200.0
    var bodyMotionAccelerationThreshold = 0.3
}

/// Main-actor-owned settings store. UserDefaults access and observation are confined to the UI actor.
@MainActor
@Observable
final class GestureSettings {
    private static let storageKey = "gestureThresholds.v1"
    private let defaults: UserDefaults

    var thresholds: GestureThresholds {
        didSet { persist() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(GestureThresholds.self, from: data) {
            thresholds = decoded
        } else {
            thresholds = GestureThresholds()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(thresholds) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
