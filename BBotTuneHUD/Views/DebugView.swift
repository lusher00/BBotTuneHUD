import SwiftUI

struct DebugView: View {
    @ObservedObject var viewModel: RobotViewModel
    @ObservedObject private var logger = AppLogger.shared

    @State private var encodersEnabled  = false
    @State private var imuFullEnabled   = false
    @State private var pidStatesEnabled = true
    @State private var motorsEnabled    = false
    @State private var logScrollProxy: ScrollViewProxy? = nil
    @State private var autoscroll = true

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // ── Log console ───────────────────────────────────────────
                ZStack(alignment: .bottomTrailing) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(logger.entries) { entry in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(entry.timeString)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .leading)
                                        Text(entry.text)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(logColor(entry.text))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .id(entry.id)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 1)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .background(Color(.systemGray6))
                        .onChange(of: logger.entries.count) { _, _ in
                            if autoscroll, let last = logger.entries.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onAppear {
                            if let last = logger.entries.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }

                    // Autoscroll + clear controls
                    VStack(spacing: 6) {
                        Button {
                            autoscroll.toggle()
                        } label: {
                            Image(systemName: autoscroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.title3)
                                .foregroundColor(autoscroll ? .accentColor : .secondary)
                        }
                        Button {
                            logger.clear()
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(10)
                }
                .frame(maxHeight: 260)

                Divider()

                // ── Telemetry controls + system status ───────────────────
                List {
                    Section(header: Text("Telemetry Streams")) {
                        Toggle("Encoder Data", isOn: $encodersEnabled)
                            .onChange(of: encodersEnabled) { _, new in viewModel.setTelemetryOptions(encoders: new) }
                        Toggle("Full IMU Data (high bandwidth)", isOn: $imuFullEnabled)
                            .onChange(of: imuFullEnabled) { _, new in viewModel.setTelemetryOptions(imuFull: new) }
                        Toggle("PID States", isOn: $pidStatesEnabled)
                            .onChange(of: pidStatesEnabled) { _, new in viewModel.setTelemetryOptions(pidStates: new) }
                        Toggle("Motor Commands", isOn: $motorsEnabled)
                    }

                    Section(header: Text("System Status")) {
                        LabeledRow("Packets rx") { Text("\(viewModel.packetsReceived)").fontWeight(.semibold) }
                        LabeledRow("Battery")    { Text(String(format: "%.2fV", viewModel.robotState.battery)).foregroundColor(viewModel.batteryColor).fontWeight(.semibold) }
                        LabeledRow("Armed")      { Text(viewModel.robotState.armed ? "YES" : "NO").foregroundColor(viewModel.robotState.armed ? .green : .red).fontWeight(.semibold) }
                        LabeledRow("Mode")       { Text(viewModel.modeName).fontWeight(.semibold) }
                        LabeledRow("Loop Hz")    { Text(String(format: "%.1f Hz", viewModel.robotState.loopHz)).fontWeight(.semibold) }
                    }

                    Section(header: Text("IMU Visualization")) {
                        LabeledRow("θ pitch") {
                            Text(String(format: "%.1f°", viewModel.robotState.imu.theta))
                                .fontWeight(.semibold).foregroundColor(.red)
                        }
                        LabeledRow("φ roll") {
                            Text(String(format: "%.1f°", viewModel.robotState.imu.phi))
                                .fontWeight(.semibold).foregroundColor(.green)
                        }
                        LabeledRow("ψ yaw") {
                            Text(String(format: "%.1f°", viewModel.robotState.imu.psi))
                                .fontWeight(.semibold).foregroundColor(.blue)
                        }
                        Button {
                            viewModel.zeroIMUDisplay()
                        } label: {
                            Label("Zero display at current angles", systemImage: "scope")
                                .foregroundColor(.accentColor)
                        }
                    }

                    if let encoders = viewModel.robotState.encoders {
                        Section(header: Text("Encoders")) {
                            HStack {
                                EncoderColumn(side: "Left",  ticks: encoders.leftTicks,  deg: encoders.leftDeg,  vel: encoders.leftDegPerSec)
                                Spacer()
                                EncoderColumn(side: "Right", ticks: encoders.rightTicks, deg: encoders.rightDeg, vel: encoders.rightDegPerSec)
                            }
                        }
                    }

                    Section(header: Text("PID Controllers")) {
                        PIDDebugRow(name: "D1 Balance",  state: viewModel.robotState.d1Balance)
                        PIDDebugRow(name: "D2 Drive",    state: viewModel.robotState.d2Drive)
                        PIDDebugRow(name: "D3 Steering", state: viewModel.robotState.d3Steering)
                    }

                    if let motors = viewModel.robotState.motors {
                        Section(header: Text("Motors")) {
                            LabeledRow("Left Duty")  { Text(String(format: "%.3f", motors.leftDuty)).fontWeight(.semibold) }
                            LabeledRow("Right Duty") { Text(String(format: "%.3f", motors.rightDuty)).fontWeight(.semibold) }
                        }
                    }

                    Section(header: Text("Connection")) {
                        LabeledRow("Status") {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.isConnected ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.isConnected ? "Connected" : "Disconnected")
                            }
                        }
                        if let error = viewModel.connectionError {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("🐛 Debug Console")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Color-code log lines by their leading emoji / keyword
    private func logColor(_ text: String) -> Color {
        if text.hasPrefix("❌") || text.hasPrefix("💔") { return .red }
        if text.hasPrefix("⚠️")                         { return .orange }
        if text.hasPrefix("✅") || text.hasPrefix("🔗") { return .green }
        if text.hasPrefix("🔫") || text.hasPrefix("🛑") { return .yellow }
        if text.hasPrefix("🎯")                         { return .purple }
        return .primary
    }
}

// ── Small reusable row ──────────────────────────────────────────────────────
struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
    }
}

struct EncoderColumn: View {
    let side: String
    let ticks: Int
    let deg: Float
    let vel: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(side).font(.caption).foregroundColor(.secondary)
            Text("\(ticks) ticks")
            Text(String(format: "%.1f°", deg)).font(.caption)
            Text(String(format: "%.1f°/s", vel)).font(.caption)
        }
    }
}

struct PIDDebugRow: View {
    let name: String
    let state: PIDState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).fontWeight(.semibold)
                Spacer()
                Text(state.enabled ? "ON" : "OFF")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(state.enabled ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            if state.enabled {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Error").font(.caption).foregroundColor(.secondary)
                        Text(String(format: "%.4f", state.error)).font(.caption)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Output").font(.caption).foregroundColor(.secondary)
                        Text(String(format: "%.4f", state.output)).font(.caption)
                    }
                }
            }
        }
    }
}

#Preview {
    DebugView(viewModel: RobotViewModel())
}
