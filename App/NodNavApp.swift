import SwiftUI

@main
struct NodNavApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NodNav", systemImage: "move.3d") {
            MenuBarContentView(
                pauseController: appDelegate.pauseController,
                coordinator: appDelegate.coordinator
            )
        }
        .menuBarExtraStyle(.window)

        Window("Head Movement", id: "headMovement") {
            HeadMovementView(coordinator: appDelegate.coordinator)
        }
        .defaultSize(width: 340, height: 540)
        .windowResizability(.contentSize)
    }
}
