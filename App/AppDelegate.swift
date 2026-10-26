import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let pauseController = PauseController()
    let gestureSettings = GestureSettings()
    let callAdapterRegistry = CallAdapterRegistry()
    private(set) lazy var coordinator = MotionPipelineCoordinator(
        router: ActionRouter(engine: ActionEngine(), pauseController: pauseController),
        pauseController: pauseController,
        thresholds: gestureSettings.thresholds
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AccessibilityPermission.isTrusted {
            AccessibilityPermission.requestIfNeeded()
        }
        coordinator.start()
    }
}
