import Foundation

/// Main-actor-owned pipeline steps 8-9: the single entry point for every action,
/// regardless of which gesture produced it. Pause state and context checks live here, per the
/// PRD's system architecture ("every action passes through one Action Router").
@MainActor
final class ActionRouter {
    private static let supportedBrowsers: Set<String> = [
        "com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser",
        "com.microsoft.edgemac", "org.mozilla.firefox", "com.brave.Browser"
    ]
    private let engine: any ActionExecuting
    private let appContext: any AppContextProviding
    private let pauseController: PauseController

    init(
        engine: any ActionExecuting,
        pauseController: PauseController,
        appContext: any AppContextProviding = WorkspaceAppContext()
    ) {
        self.engine = engine
        self.pauseController = pauseController
        self.appContext = appContext
    }

    /// Stub for FR10 (per-app rules). Always true in this slice — no frontmost-app context exists
    /// yet — but every dispatch routes through this check so later per-app rules slot in here
    /// without touching call sites.
    func isActionAllowed(_ action: Action) -> Bool {
        switch action {
        case .browserBack, .browserForward:
            guard let bundleID = appContext.frontmostApplicationBundleIdentifier else { return false }
            return Self.supportedBrowsers.contains(bundleID)
        default:
            return true
        }
    }

    func perform(_ action: Action) {
        guard !pauseController.isPaused else { return }
        guard isActionAllowed(action) else { return }
        engine.perform(action)
    }
}
