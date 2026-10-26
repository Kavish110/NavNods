import SwiftUI

struct MenuBarContentView: View {
    @Bindable var pauseController: PauseController
    @Bindable var coordinator: MotionPipelineCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NodNav").font(.headline)

            Grid(alignment: .leading) {
                GridRow {
                    Text("Pitch").foregroundStyle(.secondary)
                    Text(String(format: "%.1f°", coordinator.pose.pitch))
                }
                GridRow {
                    Text("Yaw").foregroundStyle(.secondary)
                    Text(String(format: "%.1f°", coordinator.pose.yaw))
                }
                GridRow {
                    Text("Roll").foregroundStyle(.secondary)
                    Text(String(format: "%.1f°", coordinator.pose.roll))
                }
            }
            .font(.system(.body, design: .monospaced))

            Label(coordinator.trackingStatusDescription, systemImage: coordinator.sourceKind == .liveAirPods ? "airpodspro" : "waveform.path")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Last action: \(coordinator.lastActionDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Picker("Motion source", selection: $coordinator.sourceKind) {
                Text("Live AirPods").tag(MotionSourceKind.liveAirPods)
                Text("Simulated lean (preview only)").tag(MotionSourceKind.simulatedLean)
                Text("Simulated scroll (preview only)").tag(MotionSourceKind.simulatedScroll)
            }
            .pickerStyle(.radioGroup)

            Divider()

            Button("Head Movement Monitor…") {
                openWindow(id: "headMovement")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button(pauseController.isPaused ? "Resume" : "Pause") {
                pauseController.toggle()
            }
            Button("Recalibrate") {
                coordinator.recalibrate()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}
