import AppKit

/// Main-actor boundary for querying the foreground application. Tests inject deterministic contexts.
@MainActor
protocol AppContextProviding: AnyObject {
    var frontmostApplicationBundleIdentifier: String? { get }
}

@MainActor
final class WorkspaceAppContext: AppContextProviding {
    var frontmostApplicationBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
