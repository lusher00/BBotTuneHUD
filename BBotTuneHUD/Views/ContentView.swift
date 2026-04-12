import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RobotViewModel()
    @State private var selectedTab = 0

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            if landscape {
                // Landscape — full-screen graph, no tab bar
                PIDGraphView(viewModel: viewModel)
                    .ignoresSafeArea()
            } else {
                // Portrait — full tab navigation, graph included
                TabView(selection: $selectedTab) {
                    ControlView(viewModel: viewModel)
                        .tabItem { Label("Control",  systemImage: "video.circle.fill") }
                        .tag(0)
                    PIDTuningView(viewModel: viewModel)
                        .tabItem { Label("PID",      systemImage: "slider.horizontal.3") }
                        .tag(1)
                    PIDGraphView(viewModel: viewModel)
                        .tabItem { Label("Graphs",   systemImage: "chart.xyaxis.line") }
                        .tag(2)
                    IMUVisualizationView(viewModel: viewModel)
                        .tabItem { Label("3D IMU",   systemImage: "cube.fill") }
                        .tag(3)
                    XboxStatusView(viewModel: viewModel)
                        .tabItem { Label("Xbox",     systemImage: "gamecontroller.fill") }
                        .tag(4)
                    DebugView(viewModel: viewModel)
                        .tabItem { Label("Debug",    systemImage: "ant.fill") }
                        .tag(5)
                    SettingsView(viewModel: viewModel)
                        .tabItem { Label("Settings", systemImage: "gear") }
                        .tag(6)
                }
            }
        }
        .onAppear { viewModel.connect() }
    }
}

#Preview { ContentView() }
