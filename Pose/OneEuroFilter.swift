import Foundation

/// Low jitter at rest, low lag during fast moves. Used to smooth pitch, yaw and roll independently.
/// Reference: Casiez, Roussel, Vogel — "1€ Filter" (CHI 2012).
nonisolated struct OneEuroFilter {
    var minCutoff: Double
    var beta: Double
    var dCutoff: Double

    private var xFilter = LowPassFilter()
    private var dxFilter = LowPassFilter()
    private var lastTimestamp: TimeInterval?

    init(minCutoff: Double = 1.0, beta: Double = 0.0, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    mutating func filter(value: Double, timestamp: TimeInterval) -> Double {
        guard let last = lastTimestamp else {
            lastTimestamp = timestamp
            return xFilter.filter(value, alpha: 1.0)
        }
        let dt = max(timestamp - last, 1e-6)
        lastTimestamp = timestamp

        let previous = xFilter.lastValue ?? value
        let derivative = (value - previous) / dt
        let smoothedDerivative = dxFilter.filter(derivative, alpha: Self.alpha(cutoff: dCutoff, dt: dt))

        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        return xFilter.filter(value, alpha: Self.alpha(cutoff: cutoff, dt: dt))
    }

    mutating func reset() {
        xFilter = LowPassFilter()
        dxFilter = LowPassFilter()
        lastTimestamp = nil
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1.0 / (2.0 * .pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }
}

nonisolated private struct LowPassFilter {
    private(set) var lastValue: Double?

    mutating func filter(_ value: Double, alpha: Double) -> Double {
        let result: Double
        if let last = lastValue {
            result = alpha * value + (1.0 - alpha) * last
        } else {
            result = value
        }
        lastValue = result
        return result
    }
}
