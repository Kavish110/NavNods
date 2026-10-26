import SceneKit
import SwiftUI

/// A 3D head model (loaded from 3Dhead.usdz) that rotates live to match the filtered pose,
/// giving an at-a-glance emulation of head movement alongside the numeric axis readouts.
struct HeadSceneView: NSViewRepresentable {
    var pose: FilteredPose

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = Self.buildScene()
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        guard let headRig = nsView.scene?.rootNode.childNode(withName: "headRig", recursively: false) else { return }
        headRig.simdOrientation = Self.displayOrientation(for: pose)
    }

    /// The pipeline follows CoreMotion's naming (pitch = X, roll = Y, yaw = Z). This model's
    /// SceneKit axes are X = nod, Y = shake, Z = tilt, so nod and shake map directly (nod with an
    /// inverted sign) and roll is shown on Z. Display only; gesture logic is untouched.
    private static func displayOrientation(for pose: FilteredPose) -> simd_quatf {
        let nod = simd_quatf(angle: Float(-pose.pitch * .pi / 180), axis: SIMD3<Float>(1, 0, 0))
        let shake = simd_quatf(angle: Float(pose.yaw * .pi / 180), axis: SIMD3<Float>(0, 1, 0))
        let tilt = simd_quatf(angle: Float(pose.roll * .pi / 180), axis: SIMD3<Float>(0, 0, 1))
        return tilt * shake * nod
    }

    private static func buildScene() -> SCNScene {
        let scene = SCNScene()

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0, 3.4)
        scene.rootNode.addChildNode(camera)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .omni
        keyLight.light?.intensity = 900
        keyLight.position = SCNVector3(2, 3, 4)
        scene.rootNode.addChildNode(keyLight)

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 350
        scene.rootNode.addChildNode(ambientLight)

        let headRig = SCNNode()
        headRig.name = "headRig"
        scene.rootNode.addChildNode(headRig)

        if let model = loadHeadModel() {
            headRig.addChildNode(model)
        }

        return scene
    }

    /// Loads 3Dhead.usdz and re-centers/normalizes its scale so it fills the preview frame
    /// consistently regardless of the model's native units. `convertToYUp` reorients the
    /// asset from its native up-axis to SceneKit's Y-up/-Z-forward convention, so it faces
    /// the camera correctly without a hardcoded rotation fix.
    private static func loadHeadModel() -> SCNNode? {
        guard let url = Bundle.main.url(forResource: "3Dhead", withExtension: "usdz"),
              let modelScene = try? SCNScene(url: url, options: [.convertToYUp: true]) else { return nil }

        let container = SCNNode()
        for child in modelScene.rootNode.childNodes {
            container.addChildNode(child)
        }
        makeDoubleSided(container)

        let (minV, maxV) = container.boundingBox
        let size = SCNVector3(maxV.x - minV.x, maxV.y - minV.y, maxV.z - minV.z)
        let maxDimension = max(size.x, max(size.y, size.z))
        guard maxDimension > 0 else { return container }

        let targetDiameter: CGFloat = 1.8
        let scale = targetDiameter / maxDimension
        container.scale = SCNVector3(scale, scale, scale)

        let center = SCNVector3((minV.x + maxV.x) / 2, (minV.y + maxV.y) / 2, (minV.z + maxV.z) / 2)
        container.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)

        return container
    }

    /// The USDZ's materials cull backfaces by default, which hides most of the head when it
    /// rotates toward edge-on angles; rendering both sides keeps it solid at any pose.
    private static func makeDoubleSided(_ node: SCNNode) {
        node.geometry?.materials.forEach { $0.isDoubleSided = true }
        node.childNodes.forEach(makeDoubleSided)
    }
}
