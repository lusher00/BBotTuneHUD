import SwiftUI
import SceneKit

// ============================================================
// IMU Display Configuration
// Per-axis trim offsets in DEGREES. Applied before rendering.
// ============================================================
struct IMUDisplayConfig {
    var pitchOffset: Float = 0.0   // theta trim (degrees)
    var rollOffset:  Float = 0.0   // phi trim   (degrees)
    var yawOffset:   Float = 0.0   // psi trim   (degrees)
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
                    // theta/phi/psi arrive already in degrees, axis-mapped
                    // and offset-corrected by imu_config_apply_transform().
                    // 0° = robot balanced upright.
                    GroupBox(label: Text("IMU Angles").font(.headline)) {
                        VStack(spacing: 8) {
                            AngleRow(label: "θ  pitch  [IMU-Y]  fwd/back lean", value: viewModel.robotState.imu.theta, color: .red)
                            AngleRow(label: "φ  roll   [IMU-X]  side lean",     value: viewModel.robotState.imu.phi,   color: .green)
                            AngleRow(label: "ψ  yaw    [IMU-Z]  turning",       value: viewModel.robotState.imu.psi,   color: .blue)
                        }
                    }
                    .padding(.horizontal)

                    // ── Angular rates ────────────────────────────────────
                    GroupBox(label: Text("Angular Rates").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            RateLabel(title: "θ̇  pitch rate  [IMU-Y]", value: viewModel.robotState.imu.thetaDot)
                            RateLabel(title: "φ̇  roll rate   [IMU-X]", value: viewModel.robotState.imu.phiDot)
                            RateLabel(title: "ψ̇  yaw rate    [IMU-Z]", value: viewModel.robotState.imu.psiDot)
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

            OffsetSlider(label: "Pitch offset (°)", value: $config.pitchOffset, range: -45...45)
            OffsetSlider(label: "Roll offset (°)",  value: $config.rollOffset,  range: -45...45)
            OffsetSlider(label: "Yaw offset (°)",   value: $config.yawOffset,   range: -180...180)

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
// Driven from the DMP quaternion — no Euler reconstruction,
// no gimbal lock.
//
// The cube faces are labeled with IMU body axes (+X/+Y/+Z).
// theta (pitch) is rotation around IMU-Y.
// The qRemap aligns IMU-Y with SceneKit-Y (vertical on screen)
// so that pitch — the balance axis — tilts the cube
// forward/back as you'd expect.
//
// Trim sliders in IMUDisplayConfig are small corrective
// rotations applied in quaternion space after the remap.
// ============================================================
struct CubeSceneView: UIViewRepresentable {
    let imu: IMUData
    let config: IMUDisplayConfig

    class Coordinator: NSObject {
        var cubeNode: SCNNode?
        // Aligns IMU-Y (pitch axis) with SceneKit-Y (screen vertical).
        // Adjust angle/axis here if the cube orientation looks wrong.
        let qRemap = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 0, 1))
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
        let coord = context.coordinator

        // ── Pull quaternion from telemetry ───────────────────────────────
        guard let qw = imu.qw, let qx = imu.qx,
              let qy = imu.qy, let qz = imu.qz,
              qw.isFinite && qx.isFinite && qy.isFinite && qz.isFinite
        else { return }

        // DMP quaternion in IMU body frame
        let qDMP = simd_normalize(simd_quatf(ix: qx, iy: qy, iz: qz, r: qw))

        // Remap IMU body frame → SceneKit display frame
        var target = simd_normalize(coord.qRemap * qDMP)

        // ── Apply display trim offsets (degrees → small corrective quats) ─
        // These are tiny visual adjustments, applied in the remapped frame.
        if config.pitchOffset != 0 {
            let q = simd_quatf(angle: config.pitchOffset * .pi / 180,
                               axis: SIMD3<Float>(1, 0, 0))
            target = simd_normalize(q * target)
        }
        if config.rollOffset != 0 {
            let q = simd_quatf(angle: config.rollOffset * .pi / 180,
                               axis: SIMD3<Float>(0, 0, 1))
            target = simd_normalize(q * target)
        }
        if config.yawOffset != 0 {
            let q = simd_quatf(angle: config.yawOffset * .pi / 180,
                               axis: SIMD3<Float>(0, 1, 0))
            target = simd_normalize(q * target)
        }

        // ── Slerp for smoothing ──────────────────────────────────────────
        // Ensure we take the short path (dot product check)
        var cur = node.simdOrientation
        if simd_dot(cur.vector, target.vector) < 0 {
            cur = simd_quatf(ix: -cur.imag.x, iy: -cur.imag.y,
                             iz: -cur.imag.z, r: -cur.real)
        }
        node.simdOrientation = simd_slerp(cur, target, config.smoothing)
    }

    private func createScene(coordinator: Coordinator) -> SCNScene {
        let scene = SCNScene()

        // Domino: long axis vertical, short edge on floor, large face forward.
        // width=1.5 (X), height=3.0 (Y, long axis), length=0.4 (Z, thin depth)
        let cubeGeo = SCNBox(width: 1.5, height: 3.0, length: 0.4, chamferRadius: 0.06)
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

        // Face labels — IMU body axes as mounted on the robot
        // +Y = pitch axis (forward lean direction)
        // +X = roll axis
        // +Z = yaw axis (up through robot when balancing)
        addLabel("+Z",  to: cubeNode, pos: SCNVector3( 0,     0,    0.21))
        addLabel("-Z",  to: cubeNode, pos: SCNVector3( 0,     0,   -0.21), ry: .pi)
        addLabel("+X",  to: cubeNode, pos: SCNVector3( 0.76,  0,    0),    ry:  .pi/2)
        addLabel("-X",  to: cubeNode, pos: SCNVector3(-0.76,  0,    0),    ry: -.pi/2)
        addLabel("+Y",  to: cubeNode, pos: SCNVector3( 0,     1.51, 0),    rx: -.pi/2)
        addLabel("-Y",  to: cubeNode, pos: SCNVector3( 0,    -1.51, 0),    rx:  .pi/2)

        // Fixed world-space axis arrows
        scene.rootNode.addChildNode(axisArrow(color: .systemRed,   dir: SIMD3(1, 0, 0)))
        scene.rootNode.addChildNode(axisArrow(color: .systemGreen, dir: SIMD3(0, 1, 0)))
        scene.rootNode.addChildNode(axisArrow(color: .systemBlue,  dir: SIMD3(0, 0, 1)))

        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.position = SCNVector3(0, 0.5, 7)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)

        return scene
    }

    private func makeMat(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        return m
    }

    // Renders text onto a flat SCNPlane using a CATextLayer — always readable,
    // no SCNText sizing issues.
    private func addLabel(_ text: String, to parent: SCNNode,
                          pos: SCNVector3, rx: Float = 0, ry: Float = 0) {
        let size: CGFloat = 128
        let layer = CATextLayer()
        layer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        layer.string = text
        layer.font = UIFont.boldSystemFont(ofSize: 36)
        layer.fontSize = 36
        layer.alignmentMode = .center
        layer.foregroundColor = UIColor.white.cgColor
        layer.backgroundColor = UIColor.clear.cgColor
        layer.contentsScale = 2

        let plane = SCNPlane(width: 0.6, height: 0.6)
        let mat = SCNMaterial()
        mat.diffuse.contents = layer
        mat.isDoubleSided = true
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
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
            Text(String(format: "%.1f°", value))
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
            Text(String(format: "%.1f°/s", value))
                .font(.subheadline.monospacedDigit()).fontWeight(.semibold)
        }
    }
}

#Preview {
    IMUVisualizationView(viewModel: RobotViewModel())
}
