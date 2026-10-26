import Foundation

/// Pipeline step 7: if two machines confirm within the same 150ms window, the higher normalised
/// score wins; ties are dropped rather than guessed. Trivial with one discrete gesture family today,
/// but every confirmed event should flow through here so later gestures (flick, nod, shake) slot in
/// without touching the dispatch call site.
nonisolated final class GestureArbiter {
    var arbitrationWindow: TimeInterval = 0.15

    private var pending: [GestureEvent] = []
    private var windowStart: TimeInterval?

    /// Feed a confirmed event; returns the winner once the arbitration window for its batch closes.
    /// Call `flush(upTo:)` each tick so a solitary event (the common case) is released promptly
    /// after the window elapses with nothing to compete against.
    func submit(_ event: GestureEvent) -> GestureEvent? {
        if let start = windowStart, event.timestamp - start < arbitrationWindow {
            pending.append(event)
            return nil
        }
        let resolved = resolvePending()
        pending = [event]
        windowStart = event.timestamp
        return resolved
    }

    /// Call periodically (e.g. once per pose sample) with the current time so a single pending
    /// event gets released even if nothing else arrives to close its window.
    func flush(upTo timestamp: TimeInterval) -> GestureEvent? {
        guard let start = windowStart, timestamp - start >= arbitrationWindow else { return nil }
        let resolved = resolvePending()
        windowStart = nil
        return resolved
    }

    private func resolvePending() -> GestureEvent? {
        defer { pending = [] }
        guard !pending.isEmpty else { return nil }
        guard pending.count > 1 else { return pending[0] }

        let sorted = pending.sorted { $0.confidence > $1.confidence }
        guard sorted[0].confidence != sorted[1].confidence else { return nil } // tie, drop
        return sorted[0]
    }
}
