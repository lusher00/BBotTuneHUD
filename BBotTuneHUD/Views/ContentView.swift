import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RobotViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ControlView(viewModel: viewModel)
                .tabItem {
                    Label("Control", systemImage: "video.circle.fill")
                }
                .tag(0)
            
            PIDTuningView(viewModel: viewModel)
                .tabItem {
                    Label("PID Tuning", systemImage: "slider.horizontal.3")
                }
                .tag(1)
            
            IMUVisualizationView(viewModel: viewModel)
                .tabItem {
                    Label("3D IMU", systemImage: "cube.fill")
                }
                .tag(2)
            XboxStatusView(viewModel: viewModel)
                .tabItem {
                    Label("Xbox", systemImage: "gamecontroller.fill")
                }
                .tag(3)

            DebugView(viewModel: viewModel)
                .tabItem {
                    Label("Debug", systemImage: "ant.fill")
                }
                .tag(4)
            
            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(5)
        }
        .onAppear {
            viewModel.connect()
        }
    }
}

#Preview {
    ContentView()
}
