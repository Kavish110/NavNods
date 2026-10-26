import Foundation

enum CallResponse: Sendable {
    case answer
    case decline
}

/// A main-actor service because Accessibility UI inspection and mutation target application UI.
@MainActor
protocol CallAdapter: AnyObject {
    var identifier: String { get }
    var supportedBundleIdentifiers: Set<String> { get }
    func detectIncomingCall() -> Bool
    func respond(_ response: CallResponse) -> Bool
}

/// Main-actor-owned registry that selects adapters by foreground app and incoming-call state.
@MainActor
final class CallAdapterRegistry {
    private var adaptersByBundleIdentifier: [String: any CallAdapter] = [:]

    init(adapters: [any CallAdapter] = []) {
        for adapter in adapters {
            register(adapter)
        }
    }

    func register(_ adapter: any CallAdapter) {
        for bundleIdentifier in adapter.supportedBundleIdentifiers {
            adaptersByBundleIdentifier[bundleIdentifier] = adapter
        }
    }

    func adapter(for bundleIdentifier: String) -> (any CallAdapter)? {
        adaptersByBundleIdentifier[bundleIdentifier]
    }

    func incomingCallAdapter(frontmostBundleIdentifier: String?) -> (any CallAdapter)? {
        guard let frontmostBundleIdentifier,
              let adapter = adapter(for: frontmostBundleIdentifier),
              adapter.detectIncomingCall()
        else { return nil }
        return adapter
    }
}
