import SwiftUI
import SceneKit

// ============================================================
// IMU Display Configuration
// Simple per-axis offsets (radians) to trim the visual so the
// cube sits level when the robot is balanced. No quaternion math.
// ============================================================
struct IMUDisplayConfig {
    var pitchOffset: Float = 0.0   // theta trim
    var rollOffset:  Float = 0.0   // phi trim
    var yawOffset:   Float = 0.0   // psi trim
    var smoothing:   Float = 0.2   // slerp factor (0=frozen, 1=instant)
}

struct IMUVisualizationView: View {
    @ObservedObject var viewModel: RobotViewModel
    @State private var showOrientationControls = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // ── 3D Cube ──────────────────────────────────────────
                    CubeSceneView(
                        imu: viewModel.robotState.imu,
                        config: viewModel.imuDisplayConfig
                    )
                    .frame(height: 300)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // ── Angle readouts ───────────────────────────────────
                    GroupBox(label: Text("IMU Angles").font(.headline)) {
                        VStack(spacing: 8) {
                            AngleRow(label: "Pitch  θ  (forward/back lean)", value: viewModel.robotState.imu.theta,    color: .red)
                            AngleRow(label: "Roll   φ  (side lean)",         value: viewModel.robotState.imu.phi,      color: .green)
                            AngleRow(label: "Yaw    ψ  (turning)",           value: viewModel.robotState.imu.psi,      color: .blue)
                        }
                    }
                    .padding(.horizontal)

                    // ── Angular rates ────────────────────────────────────
                    GroupBox(label: Text("Angular Rates").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            RateLabel(title: "θ̇  pitch rate", value: viewModel.robotState.imu.thetaDot)
                            RateLabel(title: "φ̇  roll rate",  value: viewModel.robotState.imu.phiDot)
                            RateLabel(title: "ψ̇  yaw rate",   value: viewModel.robotState.imu.psiDot)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)

                    // ── PID cross-check ──────────────────────────────────
                    GroupBox(label: Text("D1 Balance PID").font(.headline)) {
                        VStack(spacing: 8) {
                            AngleRow(label: "measurement (θ)", value: viewModel.robotState.d1Balance.measurement ?? 0.0, color: .orange)
                            AngleRow(label: "setpoint (θ_ref)", value: viewModel.robotState.d1Balance.setpoint, color: .orange)
                        }
                    }
                    .padding(.horizontal)

                    // ── Visual trim controls (collapsible) ───────────────
                    GroupBox {
                        VStack(spacing: 0) {
                            Button(action: { withAnimation { showOrientationControls.toggle() } }) {
                                HStack {
                                    Text("Visual Trim")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: showOrientationControls ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if showOrientationControls {
                                Divider().padding(.vertical, 8)
                                OrientationControlsView(config: $viewModel.imuDisplayConfig)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("📐 IMU Attitude")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// ============================================================
// Orientation trim controls
// ============================================================
struct OrientationControlsView: View {
    @Binding var config: IMUDisplayConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trim offsets added to each angle before rendering.")
                .font(.caption).foregroundColor(.secondary)

            OffsetSlider(label: "Pitch offset (°)",
                         value: Binding(
                            get: { config.pitchOffset * 180 / .pi },
                            set: { config.pitchOffset = $0 * .pi / 180 }),
                         range: -45...45)

            OffsetSlider(label: "Roll offset (°)",
                         value: Binding(
                            get: { config.rollOffset * 180 / .pi },
                            set: { config.rollOffset = $0 * .pi / 180 }),
                         range: -45...45)

            OffsetSlider(label: "Yaw offset (°)",
                         value: Binding(
                            get: { config.yawOffset * 180 / .pi },
                            set: { config.yawOffset = $0 * .pi / 180 }),
                         range: -180...180)

            Divider()

            OffsetSlider(label: "Smoothing", value: $config.smoothing, range: 0.01...1.0)

            Button("Reset to Defaults") { config = IMUDisplayConfig() }
                .font(.caption).foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct OffsetSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(String(format: "%.1f", value)).font(.caption).fontWeight(.semibold)
            }
            Slider(value: $value, in: range)
        }
    }
}

// ============================================================
// Cube SceneKit View
// Driven entirely by theta/phi/psi — no quaternion path.
// ============================================================
struct CubeSceneView: UIViewRepresentable {
    let imu: IMUData
    let config: IMUDisplayConfig

    class Coordinator: NSObject {
        var cubeNode: SCNNode?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = createScene(coordinator: context.coordinator)
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.systemBackground
        sceneView.allowsCameraControl = true
        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let node = context.coordinator.cubeNode else { return }

        // ── Drive cube from the same angles the PID uses ────────────────
        // Robot frame → SceneKit axes:
        //   theta (pitch, forward/back lean) → rotate about X
        //   phi   (roll,  side lean)         → rotate about Z
        //   psi   (yaw,   turning)           → rotate about Y
        //
        // Add user trim offsets so the cube can be nulled at rest.
        let pitch = imu.theta + config.pitchOffset
        let roll  = imu.phi   + config.rollOffset
        let yaw   = imu.psi   + config.yawOffset

        guard pitch.isFinite && roll.isFinite && yaw.isFinite else { return }

        // Compose intrinsic YXZ (yaw applied first, then pitch, then roll)
        let qYaw   = simd_quatf(angle: yaw,   axis: SIMD3(0, 1, 0))
        let qPitch = simd_quatf(angle: pitch,  axis: SIMD3(1, 0, 0))
        let qRoll  = simd_quatf(angle: roll,   axis: SIMD3(0, 0, 1))
        let target = simd_normalize(qYaw * qPitch * qRoll)

        node.simdOrientation = simd_slerp(node.simdOrientation, target, config.smoothing)
    }

    private func createScene(coordinator: Coordinator) -> SCNScene {
        let scene = SCNScene()

        // Tall narrow box shaped like the robot body (W x H x D)
        let cubeGeo = SCNBox(width: 1.5, height: 3.0, length: 1.0, chamferRadius: 0.06)
        cubeGeo.materials = [
            makeMat(.systemRed),
            makeMat(.systemRed.withAlphaComponent(0.3)),
            makeMat(.systemGreen),
            makeMat(.systemGreen.withAlphaComponent(0.3)),
            makeMat(.systemBlue),
            makeMat(.systemBlue.withAlphaComponent(0.3))
        ]
        let cubeNode = SCNNode(geometry: cubeGeo)
        cubeNode.name = "imuCube"
        scene.rootNode.addChildNode(cubeNode)
        coordinator.cubeNode = cubeNode

        // Face labels
        addLabel("F",   to: cubeNode, pos: SCNVector3( 0,    0,     0.51))
        addLabel("B",   to: cubeNode, pos: SCNVector3( 0,    0,    -0.51), ry: .pi)
        addLabel("+X",  to: cubeNode, pos: SCNVector3( 0.76, 0,     0),    ry:  .pi/2)
        addLabel("-X",  to: cubeNode, pos: SCNVector3(-0.76, 0,     0),    ry: -.pi/2)
        addLabel("Top", to: cubeNode, pos: SCNVector3( 0,    1.51,  0),    rx: -.pi/2)
        addLabel("Bot", to: cubeNode, pos: SCNVector3( 0,   -1.51,  0),    rx:  .pi/2)

        // Fixed world-space axis arrows
        scene.rootNode.addChildNode(axisArrow(color: .systemRed,   dir: SIMD3(1, 0, 0)))
        scene.rootNode.addChildNode(axisArrow(color: .systemGreen, dir: SIMD3(0, 1, 0)))
        scene.rootNode.addChildNode(axisArrow(color: .systemBlue,  dir: SIMD3(0, 0, 1)))

        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.position = SCNVector3(4, 3, 8)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)

        return scene
    }

    private func makeMat(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        return m
    }

    private func addLabel(_ text: String, to parent: SCNNode,
                          pos: SCNVector3, rx: Float = 0, ry: Float = 0) {
        let geo = SCNText(string: text, extrusionDepth: 0.04)
        geo.font = UIFont.boldSystemFont(ofSize: 0.4)
        geo.flatness = 0.1
        geo.firstMaterial?.diffuse.contents = UIColor.white
        let node = SCNNode(geometry: geo)
        let (mn, mx) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((mx.x - mn.x) / 2, (mx.y - mn.y) / 2, 0)
        node.position = pos
        node.eulerAngles = SCNVector3(rx, ry, 0)
        parent.addChildNode(node)
    }

    private func axisArrow(color: UIColor, dir: SIMD3<Float>) -> SCNNode {
        let length: Float = 3.5
        let cyl = SCNCylinder(radius: 0.05, height: CGFloat(length))
        cyl.materials = [makeMat(color)]
        let node = SCNNode(geometry: cyl)
        let up = SIMD3<Float>(0, 1, 0)
        let axis = cross(up, normalize(dir))
        let angle = acos(dot(up, normalize(dir)))
        if simd_length(axis) > 0.001 {
            node.simdRotation = SIMD4<Float>(normalize(axis), angle)
        }
        node.simdPosition = dir * (length / 2)
        return node
    }
}

// ============================================================
// Supporting views
// ============================================================
struct AngleRow: View {
    let label: String
    let value: Float
    let color: Color

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.1f°", value * 180 / .pi))
                .font(.subheadline.monospacedDigit())
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 65, alignment: .trailing)
        }
    }
}

struct RateLabel: View {
    let title: String
    let value: Float

    var body: some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(String(format: "%.3f rad/s", value))
                .font(.subheadline.monospacedDigit()).fontWeight(.semibold)
        }
    }
}

#Preview {
    IMUVisualizationView(viewModel: RobotViewModel())
}
