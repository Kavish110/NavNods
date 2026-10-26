import SwiftUI

/// Standalone window (opened from the menu bar) that visualises live head motion: a rotating
/// 3D head, a bar for each of pitch/yaw/roll, and a slider that scales how exaggerated that
/// motion appears to both the display and the gesture pipeline.
struct HeadMovementView: View {
    @Bindable var coordinator: MotionPipelineCoordinator

    var body: some View {
        VStack(spacing: 16) {
            HeadSceneView(pose: coordinator.pose)
                .frame(minWidth: 260, minHeight: 240)
                .background(GridBackground())
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(spacing: 10) {
                AxisBar(label: "Pitch", value: coordinator.pose.pitch, maxMagnitude: 45, color: .blue)
                AxisBar(label: "Yaw", value: coordinator.pose.yaw, maxMagnitude: 45, color: .green)
                AxisBar(label: "Roll", value: coordinator.pose.roll, maxMagnitude: 45, color: .orange)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Sensitivity")
                    Spacer()
                    Text(String(format: "%.2f×", coordinator.sensitivity))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $coordinator.sensitivity, in: 0.25...3.0, step: 0.05)
                Text("Scales how far head movement travels before it reaches gestures and scrolling.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(WindowSpaceConfigurator())
    }
}

/// Keeps this window on whatever Space the user is currently viewing. Without this, opening a
/// secondary window from an LSUIElement (menu-bar-only) app lets Mission Control switch — or
/// even create — a Space to match wherever this window last lived, instead of staying put.
private struct WindowSpaceConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.collectionBehavior.insert(.moveToActiveSpace)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Graph-paper style backdrop behind the 3D head preview, giving a fixed spatial reference so
/// rotation reads clearly against something other than a flat fill.
private struct GridBackground: View {
    let spacing: CGFloat = 16
    let majorEvery: Int = 4

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.secondary.opacity(0.08)))

            var column = 0
            var x: CGFloat = 0
            while x <= size.width {
                let isMajor = column % majorEvery == 0
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color.secondary.opacity(isMajor ? 0.3 : 0.12)), lineWidth: isMajor ? 1 : 0.5)
                x += spacing
                column += 1
            }

            var row = 0
            var y: CGFloat = 0
            while y <= size.height {
                let isMajor = row % majorEvery == 0
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.secondary.opacity(isMajor ? 0.3 : 0.12)), lineWidth: isMajor ? 1 : 0.5)
                y += spacing
                row += 1
            }
        }
    }
}

/// A center-zero horizontal gauge: the fill grows left or right from the midpoint depending on sign.
private struct AxisBar: View {
    let label: String
    let value: Double
    let maxMagnitude: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f°", value)).font(.caption.monospacedDigit())
            }
            GeometryReader { geo in
                let center = geo.size.width / 2
                let clamped = min(max(value, -maxMagnitude), maxMagnitude)
                let offset = CGFloat(clamped / maxMagnitude) * center

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))

                    Rectangle()
                        .fill(color)
                        .frame(width: abs(offset))
                        .offset(x: offset < 0 ? center + offset : center)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 1.5)
                        .offset(x: center)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 10)
        }
    }
}
