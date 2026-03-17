import Foundation
import SwiftUI
import Combine

class RobotViewModel: ObservableObject {
    @Published var robotState = RobotState()
    @Published var isConnected = false
    @Published var connectionError: String?

    @Published var pidConfig = RobotPIDConfig()
    @Published var imuDisplayConfig = IMUDisplayConfig()

    @Published var beagleboneIP = "192.168.1.140"
    @Published var rpi5IP = "192.168.1.126"

    private let webSocket = WebSocketService()
    private var cancellables = Set<AnyCancellable>()
    private var reconnectTimer: Timer?

    // Packet counter for connection health display
    @Published private(set) var packetsReceived: Int = 0

    init() {
        AppLogger.log("🚀 RobotViewModel init")
        setupWebSocket()
        startReconnectMonitoring()
    }

    private func setupWebSocket() {
        webSocket.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
                AppLogger.log(connected ? "✅ WebSocket connected" : "🔴 WebSocket disconnected")
            }
            .store(in: &cancellables)

        webSocket.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] err in
                self?.connectionError = err
                if let err { AppLogger.log("⚠️ WS error: \(err)") }
            }
            .store(in: &cancellables)

        webSocket.onTelemetryReceived = { [weak self] telemetry in
            DispatchQueue.main.async {
                self?.updateRobotState(from: telemetry)
            }
        }
    }

    private func startReconnectMonitoring() {
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if !self.isConnected {
                AppLogger.log("🔄 Auto-reconnecting to \(self.beagleboneIP)...")
                self.connect()
            }
        }
    }

    func connect() {
        AppLogger.log("🔗 connect() → \(beagleboneIP):8675")
        webSocket.connect(host: beagleboneIP, port: 8675)
    }

    func disconnect() {
        webSocket.disconnect()
    }

    func setArmed(_ armed: Bool) {
        robotState.armed = armed
        webSocket.setArmed(armed)
    }

    func setMode(_ mode: RobotMode) {
        robotState.mode = mode
        webSocket.setMode(mode.rawValue)
    }

    func savePID() {
        webSocket.savePID()
    }

    func updatePID(_ controller: String, kp: Float, ki: Float, kd: Float) {
        webSocket.setPID(controller: controller, kp: kp, ki: ki, kd: kd)
        switch controller {
        case "D1_balance":
            pidConfig.d1Balance.kp = kp
            pidConfig.d1Balance.ki = ki
            pidConfig.d1Balance.kd = kd
        case "D2_drive":
            pidConfig.d2Drive.kp = kp
            pidConfig.d2Drive.ki = ki
            pidConfig.d2Drive.kd = kd
        case "D3_steering":
            pidConfig.d3Steering.kp = kp
            pidConfig.d3Steering.ki = ki
            pidConfig.d3Steering.kd = kd
        default: break
        }
    }

    func setControllerEnabled(_ controller: String, enabled: Bool) {
        webSocket.setController(name: controller, enabled: enabled)
        switch controller {
        case "D1_balance":  pidConfig.d1Balance.enabled  = enabled
        case "D2_drive":    pidConfig.d2Drive.enabled    = enabled
        case "D3_steering": pidConfig.d3Steering.enabled = enabled
        default: break
        }
    }

    func setTelemetryOptions(encoders: Bool? = nil, imuFull: Bool? = nil, pidStates: Bool? = nil) {
        webSocket.setTelemetry(encoders: encoders, imuFull: imuFull, pidStates: pidStates)
    }

    /// Zero all three IMU display offsets using the robot's current resting angles.
    /// Tap this when the robot is sitting balanced/upright.
    func zeroIMUDisplay() {
        webSocket.zeroIMU()
        AppLogger.log("🎯 IMU zero command sent to robot")
    }

    private func updateRobotState(from telemetry: TelemetryMessage) {
        packetsReceived += 1

        if let system = telemetry.system {
            robotState.battery     = system.battery
            robotState.armed       = system.armed
            robotState.mode        = RobotMode(rawValue: system.mode) ?? .balance
            robotState.loopHz      = system.loopHz
            robotState.thetaOffset = system.thetaOffset
            robotState.battVoltage = system.battVoltage
            robotState.battStatus  = system.battStatus
        }
        if let imu      = telemetry.imu        { robotState.imu      = imu      }
        if let encoders = telemetry.encoders   { robotState.encoders = encoders }
        if let cat      = telemetry.cat        { robotState.cat      = cat      }
        if let d1       = telemetry.d1Balance  { robotState.d1Balance  = d1 }
        if let d2       = telemetry.d2Drive    { robotState.d2Drive    = d2 }
        if let d3       = telemetry.d3Steering { robotState.d3Steering = d3 }
        if let motors   = telemetry.motors     { robotState.motors   = motors   }
    }

    var videoURL: URL? {
        URL(string: "http://\(rpi5IP):5000/video_feed")
    }

    var batteryColor: Color {
        if robotState.battery > 11.5 { return .green }
        if robotState.battery > 11.0 { return .yellow }
        return .red
    }

    var battColor: Color {
        switch robotState.battStatus {
        case 1: return .green
        case 2: return .yellow
        case 3: return .red
        default: return .gray
        }
    }

    var battLabel: String {
        guard let v = robotState.battVoltage, v >= 0 else { return "–" }
        return String(format: "%.2fV", v)
    }

    var modeName: String {
        switch robotState.mode {
        case .idle:     return "Idle"
        case .balance:  return "Balance"
        case .extInput: return "Ext Control"
        case .manual:   return "Manual"
        }
    }

    deinit {
        reconnectTimer?.invalidate()
    }
}
