import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: RobotViewModel
    @FocusState private var focusedField: Field?
    
    enum Field {
        case beaglebone
        case rpi5
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Network Configuration")) {
                    VStack(alignment: .leading) {
                        Text("BeagleBone IP")
                            .font(.subheadline)
                        TextField("IP Address", text: $viewModel.beagleboneIP)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .beaglebone)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading) {
                        Text("RPi5 IP")
                            .font(.subheadline)
                        TextField("IP Address", text: $viewModel.rpi5IP)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .rpi5)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Button(action: {
                        focusedField = nil
                        viewModel.disconnect()
                        viewModel.connect()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reconnect")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                Section(header: Text("Quick Presets")) {
                    Button("Local Network (192.168.1.x)") {
                        focusedField = nil
                        viewModel.beagleboneIP = "192.168.1.100"
                        viewModel.rpi5IP = "192.168.1.139"
                    }
                    
                    Button("Local Network (10.0.0.x)") {
                        focusedField = nil
                        viewModel.beagleboneIP = "10.0.0.100"
                        viewModel.rpi5IP = "10.0.0.139"
                    }
                    
                    Button("USB Tethering") {
                        focusedField = nil
                        viewModel.beagleboneIP = "192.168.7.2"
                        viewModel.rpi5IP = "192.168.7.3"
                    }
                }
                
                Section(header: Text("App Information")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2026.02.20")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("About")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Balance Bot Control")
                            .font(.headline)
                        Text("Self-balancing robot with real-time telemetry and PID tuning")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        Text("Features:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        FeatureRow(icon: "gamecontroller.fill", text: "Real-time control")
                        FeatureRow(icon: "slider.horizontal.3", text: "Live PID tuning")
                        FeatureRow(icon: "cube.fill", text: "3D IMU visualization")
                        FeatureRow(icon: "cat.fill", text: "Cat following mode")
                        FeatureRow(icon: "ant.fill", text: "Advanced debugging")
                    }
                }
            }
            .navigationTitle("⚙️ Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onTapGesture {
                focusedField = nil
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
        }
    }
}

#Preview {
    SettingsView(viewModel: RobotViewModel())
}
