import SwiftUI

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct PIDTuningView: View {
    @ObservedObject var viewModel: RobotViewModel
    @State private var selectedController = "D1_balance"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Controller", selection: $selectedController) {
                        Text("D1: Balance").tag("D1_balance")
                        Text("D2: Position").tag("D2_drive")
                        Text("D3: Steering").tag("D3_steering")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .onChange(of: selectedController) { _ in
                        UIApplication.shared.endEditing()
                    }

                    if selectedController == "D1_balance" {
                        PIDControllerCard(
                            config: $viewModel.pidConfig.d1Balance,
                            state: viewModel.robotState.d1Balance,
                            gainsReady: viewModel.gainsReceived,
                            onUpdate: { viewModel.updatePID("D1_balance", kp: $0, ki: $1, kd: $2) },
                            onToggle: { viewModel.setControllerEnabled("D1_balance", enabled: $0) }
                        )
                    } else if selectedController == "D2_drive" {
                        PosControllerCard(
                            config: $viewModel.posConfig,
                            state: viewModel.robotState.d2Drive,
                            ready: viewModel.posConfigReceived,
                            onUpdate: { viewModel.setPosConfig($0) },
                            onToggle: { viewModel.setControllerEnabled("D2_drive", enabled: $0) }
                        )
                    } else {
                        PIDControllerCard(
                            config: $viewModel.pidConfig.d3Steering,
                            state: viewModel.robotState.d3Steering,
                            gainsReady: viewModel.gainsReceived,
                            onUpdate: { viewModel.updatePID("D3_steering", kp: $0, ki: $1, kd: $2) },
                            onToggle: { viewModel.setControllerEnabled("D3_steering", enabled: $0) }
                        )
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { UIApplication.shared.endEditing() }
            }
            .navigationTitle("⚙️ PID Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.refreshGains() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.savePID() }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
    }
}

// MARK: - D2 Position Controller Card

struct PosControllerCard: View {
    @Binding var config: PosConfig
    let state: PIDState
    let ready: Bool
    let onUpdate: (PosConfig) -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("D2: Position Hold")
                        .font(.title2).fontWeight(.bold)
                    Text("Encoder ticks \u{2192} Lean angle bias \u{2022} Keeps bot in place")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button { onToggle(!state.enabled) } label: {
                    Text(state.enabled ? "ON" : "OFF")
                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(state.enabled ? Color.green : Color.gray)
                        .cornerRadius(8)
                }
            }

            Divider()

            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 24) {

                    // Hold mode
                    VStack(alignment: .leading, spacing: 8) {
                        PosHeader("HOLD MODE")
                        Picker("Hold Mode", selection: Binding(
                            get: { config.backToSpot == 1 },
                            set: { config.backToSpot = $0 ? 1 : 0; onUpdate(config) }
                        )) {
                            Text("Full hold (A/B/C/D)").tag(true)
                            Text("Loose hold (D only)").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        Text(config.backToSpot == 1
                            ? "Corrects from any distance using all zones"
                            : "Only corrects tight deadband; drifts freely beyond zone C")
                            .font(.caption2).foregroundColor(.secondary)
                    }

                    Divider()

                    // Zone thresholds
                    VStack(alignment: .leading, spacing: 12) {
                        PosHeader("ZONE THRESHOLDS  (ticks)")
                        PIDSlider(title: "Zone A (outer)", value: i32Bind(\.zoneA), range: 1000...30000, step: 500) { onUpdate(config) }
                        PIDSlider(title: "Zone B",         value: i32Bind(\.zoneB), range: 500...15000,  step: 250) { onUpdate(config) }
                        PIDSlider(title: "Zone C (inner)", value: i32Bind(\.zoneC), range: 100...5000,   step: 100) { onUpdate(config) }
                    }

                    Divider()

                    // Scale factors
                    VStack(alignment: .leading, spacing: 12) {
                        PosHeader("SCALE FACTORS  (ticks \u{00F7} scale \u{2192} lean \u{00B0})")
                        Text("Higher = softer. Lower = more aggressive.")
                            .font(.caption2).foregroundColor(.secondary)
                        PIDSlider(title: "Scale A", value: $config.scaleA, range: 10...3000, step: 10) { onUpdate(config) }
                        PIDSlider(title: "Scale B", value: $config.scaleB, range: 10...3000, step: 10) { onUpdate(config) }
                        PIDSlider(title: "Scale C", value: $config.scaleC, range: 10...3000, step: 10) { onUpdate(config) }
                        PIDSlider(title: "Scale D (deadband)", value: $config.scaleD, range: 1...2000, step: 1) { onUpdate(config) }
                    }

                    Divider()

                    // Velocity scales
                    VStack(alignment: .leading, spacing: 12) {
                        PosHeader("VELOCITY SCALES  (vel \u{00F7} scale \u{2192} damp \u{00B0})")
                        PIDSlider(title: "Stop damping",      value: $config.velScaleStop,    range: 10...300, step: 5) { onUpdate(config) }
                        PIDSlider(title: "Move compensation", value: $config.velScaleMove,    range: 10...300, step: 5) { onUpdate(config) }
                        PIDSlider(title: "Turn scale-down",   value: $config.velScaleTurning, range: 10...300, step: 5) { onUpdate(config) }
                        Text("Turn scale-down reduces steering at speed (Balanduino style).")
                            .font(.caption2).foregroundColor(.secondary)
                    }

                    Divider()

                    // Limits
                    VStack(alignment: .leading, spacing: 12) {
                        PosHeader("LIMITS")
                        PIDSlider(title: "Max correction (\u{00B0})", value: $config.maxCorrection, range: 0.05...20, step: 0.05) { onUpdate(config) }
                        PIDSlider(title: "Max rate (\u{00B0}/tick)",   value: $config.maxAngleRate,  range: 0.01...5,  step: 0.01) { onUpdate(config) }
                        PIDSlider(title: "Stopped threshold (tk/100ms)", value: i32Bind(\.stoppedVel), range: 0...200, step: 1) { onUpdate(config) }
                        Text("Max rate limits how fast D2 shifts the balance angle \u{2014} prevents oscillation.")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                .disabled(!ready)
                .opacity(ready ? 1.0 : 0.35)

                if !ready {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
                        Text("Waiting for config from bot\u{2026}")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top, 24)
                }
            }

            Divider()

            // Live readout
            if state.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Status").font(.headline)
                    HStack(spacing: 20) {
                        StatusLabel(title: "Target",   value: state.setpoint,         format: "%.0f tk")
                        StatusLabel(title: "Position", value: state.measurement ?? 0, format: "%.0f tk")
                        StatusLabel(title: "Error",    value: state.error,             format: "%.0f tk")
                        StatusLabel(title: "Velocity", value: state.dTerm ?? 0,       format: "%.0f")
                    }
                    GeometryReader { geo in
                        let maxErr = Float(config.zoneA)
                        let frac = CGFloat(min(abs(state.error) / max(maxErr, 1), 1.0))
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.gray.opacity(0.2))
                            Rectangle()
                                .fill(abs(state.error) < Float(config.zoneC) ? Color.green :
                                      abs(state.error) < Float(config.zoneB) ? Color.yellow : Color.orange)
                                .frame(width: geo.size.width * frac)
                        }
                    }
                    .frame(height: 8).cornerRadius(4)
                    Text("Green < zone C  \u{00B7}  Yellow < zone B  \u{00B7}  Orange \u{2265} zone B")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func i32Bind(_ kp: WritableKeyPath<PosConfig, Int32>) -> Binding<Float> {
        Binding(get: { Float(config[keyPath: kp]) },
                set: { config[keyPath: kp] = Int32($0) })
    }
}

private struct PosHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
    }
}

// MARK: - Standard PID card (D1 / D3)

struct PIDControllerCard: View {
    @Binding var config: PIDConfig
    let state: PIDState
    let gainsReady: Bool
    let onUpdate: (Float, Float, Float) -> Void
    let onToggle: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text(config.name).font(.title2).fontWeight(.bold)
                    Text(desc).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    let next = !state.enabled; config.enabled = next; onToggle(next)
                } label: {
                    Text(state.enabled ? "ON" : "OFF")
                        .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(state.enabled ? Color.green : Color.gray)
                        .cornerRadius(8)
                }
            }
            Divider()
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 15) {
                    PIDSlider(title: "Kp", value: $config.kp, range: -200...200, step: 1.0,
                              onChange: { onUpdate(config.kp, config.ki, config.kd) })
                    PIDSlider(title: "Ki", value: $config.ki, range: -10...10,   step: 0.01,
                              onChange: { onUpdate(config.kp, config.ki, config.kd) })
                    PIDSlider(title: "Kd", value: $config.kd, range: -50...50,   step: 0.1,
                              onChange: { onUpdate(config.kp, config.ki, config.kd) })
                }
                .disabled(!gainsReady).opacity(gainsReady ? 1.0 : 0.35)
                if !gainsReady {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
                        Text("Waiting for gains from bot\u{2026}").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top, 24)
                }
            }
            Divider()
            if state.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Status").font(.headline)
                    HStack {
                        StatusLabel(title: "Error",  value: state.error,  format: "%.3f")
                        Spacer()
                        StatusLabel(title: "Output", value: state.output, format: "%.3f")
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.gray.opacity(0.2))
                            Rectangle()
                                .fill(state.output >= 0 ? Color.blue : Color.orange)
                                .frame(width: g.size.width * CGFloat(min(abs(state.output), 1.0)))
                        }
                    }
                    .frame(height: 20).cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    var desc: String {
        switch config.name {
        case "D1: Balance":  return "Angle \u{2192} Motor torque \u{2022} Keeps robot upright"
        case "D3: Steering": return "Yaw \u{2192} Motor differential \u{2022} Turns left/right"
        default: return ""
        }
    }
}

// MARK: - UIKit-backed text field with guaranteed Done button on decimal pad

struct DoneTextField: UIViewRepresentable {
    @Binding var text: String
    var onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .decimalPad
        tf.textAlignment = .center
        tf.borderStyle = .roundedRect
        tf.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        tf.delegate = context.coordinator

        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        bar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        ]
        bar.sizeToFit()
        tf.inputAccessoryView = bar
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if tf.text != text { tf.text = text }
        // Auto-focus when view appears
        DispatchQueue.main.async {
            if !tf.isFirstResponder { tf.becomeFirstResponder() }
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DoneTextField
        init(_ parent: DoneTextField) { self.parent = parent }

        @objc func doneTapped() { parent.onDone() }

        func textFieldDidChangeSelection(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }
    }
}

// MARK: - Shared

struct PIDSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float
    let onChange: () -> Void

    @State private var editingText = ""
    @State private var isEditing = false
    @State private var scale: Float = 1.0

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $scale) {
                Text("×1").tag(Float(1))
                Text("×10").tag(Float(10))
                Text("×100").tag(Float(100))
            }
            .pickerStyle(.segmented)
            .frame(width: 110)

            Button {
                value = max(range.lowerBound, (value - step * scale).rounded(toPlaces: 3))
                onChange()
            } label: { Image(systemName: "minus.circle").font(.title3) }
                .buttonStyle(.plain).foregroundColor(.secondary)

            if isEditing {
                DoneTextField(text: $editingText, onDone: commitEdit)
                    .frame(width: 72, height: 34)
            } else {
                Text(String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.3f", value))
                    .font(.subheadline.monospacedDigit()).fontWeight(.bold).foregroundColor(.blue)
                    .frame(width: 72).contentShape(Rectangle())
                    .onTapGesture { editingText = String(format: "%.3f", value); isEditing = true }
            }

            Button {
                value = min(range.upperBound, (value + step * scale).rounded(toPlaces: 3))
                onChange()
            } label: { Image(systemName: "plus.circle").font(.title3) }
                .buttonStyle(.plain).foregroundColor(.secondary)
        }
    }

    private func commitEdit() {
        if let f = Float(editingText) { value = min(range.upperBound, max(range.lowerBound, f)); onChange() }
        isEditing = false
    }
}

extension Float {
    func rounded(toPlaces places: Int) -> Float {
        let d = pow(10.0, Float(places)); return (self * d).rounded() / d
    }
}

struct StatusLabel: View {
    let title: String; let value: Float; let format: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(String(format: format, value)).font(.body).fontWeight(.semibold)
        }
    }
}

#Preview { PIDTuningView(viewModel: RobotViewModel()) }
