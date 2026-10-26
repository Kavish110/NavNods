import ApplicationServices
import Foundation

/// Thin wrapper around the Accessibility trust check. No entitlement is required — this is a
/// runtime TCC permission the user grants in System Settings.
enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system permission dialog if not already trusted.
    @discardableResult
    static func requestIfNeeded() -> Bool {
        // String value of kAXTrustedCheckOptionPrompt; the global itself is a mutable var that
        // Swift 6 strict concurrency rejects.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
