import SwiftUI

struct PIDTuningView: View {
    @ObservedObject var viewModel: RobotViewModel
    @State private var selectedController = "D1_balance"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Controller Selection
                    Picker("Controller", selection: $selectedController) {
                        Text("D1: Balance").tag("D1_balance")
                        Text("D2: Drive").tag("D2_drive")
                        Text("D3: Steering").tag("D3_steering")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Current Controller
                    if selectedController == "D1_balance" {
                        PIDControllerCard(
                            config: $viewModel.pidConfig.d1Balance,
                            state: viewModel.robotState.d1Balance,
                            onUpdate: { viewModel.updatePID("D1_balance", kp: $0, ki: $1, kd: $2) },
                            onToggle: { viewModel.setControllerEnabled("D1_balance", enabled: $0) }
                        )
                    } else if selectedController == "D2_drive" {
                        PIDControllerCard(
                            config: $viewModel.pidConfig.d2Drive,
                            state: viewModel.robotState.d2Drive,
                            onUpdate: { viewModel.updatePID("D2_drive", kp: $0, ki: $1, kd: $2) },
                            onToggle: { viewModel.setControllerEnabled("D2_drive", enabled: $0) }
                        )
                    } else {
                        PIDControllerCard(
                            config: $viewModel.pidConfig.d3Steering,
                            state: viewModel.robotState.d3Steering,
                            onUpdate: { viewModel.updatePID("D3_steering", kp: $0, ki: $1, kd: $2) },
                            onToggle: { viewModel.setControllerEnabled("D3_steering", enabled: $0) }
                        )
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("⚙️ PID Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.savePID() }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
    }
}

struct PIDControllerCard: View {
    @Binding var config: PIDConfig
    let state: PIDState
    let onUpdate: (Float, Float, Float) -> Void
    let onToggle: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with enable toggle
            HStack {
                VStack(alignment: .leading) {
                    Text(config.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(descriptionForController(config.name))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { config.enabled },
                    set: { newValue in
                        config.enabled = newValue
                        onToggle(newValue)
                    }
                ))
                .labelsHidden()
            }
            
            Divider()
            
            // PID Gains
            VStack(alignment: .leading, spacing: 15) {
                PIDSlider(
                    title: "Proportional (Kp)",
                    value: $config.kp,
                    range: 0...100,
                    onChange: {
                        onUpdate(config.kp, config.ki, config.kd)
                    }
                )
                
                PIDSlider(
                    title: "Integral (Ki)",
                    value: $config.ki,
                    range: 0...10,
                    onChange: {
                        onUpdate(config.kp, config.ki, config.kd)
                    }
                )
                
                PIDSlider(
                    title: "Derivative (Kd)",
                    value: $config.kd,
                    range: 0...20,
                    onChange: {
                        onUpdate(config.kp, config.ki, config.kd)
                    }
                )
            }
            
            Divider()
            
            // Live Status
            if state.enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Status")
                        .font(.headline)
                    
                    HStack {
                        StatusLabel(title: "Error", value: state.error, format: "%.3f")
                        Spacer()
                        StatusLabel(title: "Output", value: state.output, format: "%.3f")
                    }
                    
                    // Output visualization
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                            
                            Rectangle()
                                .fill(state.output >= 0 ? Color.blue : Color.orange)
                                .frame(width: geometry.size.width * CGFloat(abs(state.output)))
                        }
                    }
                    .frame(height: 20)
                    .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func descriptionForController(_ name: String) -> String {
        switch name {
        case "D1: Balance":
            return "Angle → Motor torque • Keeps robot upright"
        case "D2: Drive":
            return "Position → Lean angle • Drives forward/back"
        case "D3: Steering":
            return "Yaw → Motor differential • Turns left/right"
        default:
            return ""
        }
    }
}

struct PIDSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Slider(value: $value, in: range, onEditingChanged: { editing in
                if !editing {
                    onChange()
                }
            })
        }
    }
}

struct StatusLabel: View {
    let title: String
    let value: Float
    let format: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: format, value))
                .font(.body)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    PIDTuningView(viewModel: RobotViewModel())
}
