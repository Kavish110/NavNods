import Foundation

/// Emitted by a GestureStateMachine when it reaches Confirmed (pipeline step 6).
nonisolated struct GestureEvent: Sendable {
    var kind: GestureKind
    /// Normalised 0...1, used by the arbiter to break ties between simultaneously-confirmed gestures.
    var confidence: Double
    var timestamp: TimeInterval
}
