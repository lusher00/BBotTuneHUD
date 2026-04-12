import SwiftUI
import WebKit

struct ControlView: View {
    @ObservedObject var viewModel: RobotViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Video Feed
                    VideoPlayerView(url: viewModel.videoURL)
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(
                            CatOverlayView(cat: viewModel.robotState.cat)
                        )
                    
                    // Status Cards
                    HStack(spacing: 15) {
                        StatusCard(
                            title: "Battery",
                            value: viewModel.battLabel,
                            color: viewModel.battColor
                        )
                        
                        StatusCard(
                            title: "Angle",
                            value: String(format: "%.1f°", viewModel.robotState.imu.theta),
                            color: abs(viewModel.robotState.imu.theta) < 5 ? .green :
                                   abs(viewModel.robotState.imu.theta) < 14 ? .yellow : .red
                        )
                        
                        StatusCard(
                            title: "Loop",
                            value: String(format: "%.0fHz", viewModel.robotState.loopHz),
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                    
                    // Arm/Disarm + Zero IMU
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.setArmed(!viewModel.robotState.armed)
                        }) {
                            HStack {
                                Image(systemName: viewModel.robotState.armed ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 30))
                                Text(viewModel.robotState.armed ? "DISARM" : "ARM")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(viewModel.robotState.armed ? Color.red : Color.green)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            viewModel.zeroIMUDisplay()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "scope")
                                    .font(.system(size: 22))
                                Text("ZERO")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(width: 70)
                            .frame(height: 60)
                            .background(Color.indigo)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Mode Selection
                    VStack(alignment: .leading) {
                        Text("Mode")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("Mode", selection: Binding(
                            get: { viewModel.robotState.mode },
                            set: { viewModel.setMode($0) }
                        )) {
                            Text("Balance").tag(RobotMode.balance)
                            Text("Ext Control").tag(RobotMode.extInput)
                            Text("Manual").tag(RobotMode.manual)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    
                    // Cat Detection Status
                    if let cat = viewModel.robotState.cat, cat.detected {
                        CatStatusView(cat: cat)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("🤖 Balance Bot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ConnectionStatusView(isConnected: viewModel.isConnected)
                }
            }
        }
    }
}

// MARK: - Video Player (WKWebView — handles MJPEG multipart/x-mixed-replace)

struct VideoPlayerView: UIViewRepresentable {
    let url: URL?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = url else { return }
        // Only reload if the URL actually changed
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

// MARK: - Supporting Views

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CatStatusView: View {
    let cat: CatData
    
    var body: some View {
        HStack {
            Image(systemName: "cat.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading) {
                Text("Cat Detected")
                    .font(.headline)
                Text(String(format: "Position: (%.2f, %.2f) • %.0f%% confidence",
                           cat.x, cat.y, cat.confidence * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ConnectionStatusView: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Offline")
                .font(.caption)
        }
    }
}

struct CatOverlayView: View {
    let cat: CatData?
    
    var body: some View {
        GeometryReader { geometry in
            if let cat = cat, cat.detected {
                let centerX = geometry.size.width / 2 + CGFloat(cat.x) * geometry.size.width / 2
                let centerY = geometry.size.height / 2 + CGFloat(cat.y) * geometry.size.height / 2
                
                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .position(x: centerX, y: centerY)
                
                Path { path in
                    path.move(to: CGPoint(x: centerX - 10, y: centerY))
                    path.addLine(to: CGPoint(x: centerX + 10, y: centerY))
                    path.move(to: CGPoint(x: centerX, y: centerY - 10))
                    path.addLine(to: CGPoint(x: centerX, y: centerY + 10))
                }
                .stroke(Color.green, lineWidth: 2)
            }
        }
    }
}

#Preview {
    ControlView(viewModel: RobotViewModel())
}
