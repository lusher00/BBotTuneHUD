import Foundation
import Combine

/// WebSocket service for communicating with balance_bot
class WebSocketService: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var currentURL: URL?

    var onTelemetryReceived: ((TelemetryMessage) -> Void)?

    // MARK: - Connect / Disconnect

    func connect(host: String, port: Int = 8080) {
        guard let url = URL(string: "ws://\(host):\(port)") else {
            DispatchQueue.main.async { self.lastError = "Invalid URL" }
            return
        }

        if isConnected, currentURL == url { return }

        currentURL = url
        openSocket(url: url)
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        DispatchQueue.main.async {
            self.isConnected = false
        }
        AppLogger.log("🔌 WebSocket disconnected")
    }

    private func openSocket(url: URL) {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        AppLogger.log("🔗 Connecting to \(url)...")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 10
        config.timeoutIntervalForResource = 60
        session   = URLSession(configuration: config)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        DispatchQueue.main.async {
            self.isConnected = true
            self.lastError   = nil
        }

        receiveMessage()
        startPingTimer()
    }

    // MARK: - Receive loop

    private func receiveMessage() {
        guard let webSocket = webSocket else { return }

        webSocket.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                if self.webSocket === webSocket {
                    self.receiveMessage()
                }

            case .failure(let error):
                AppLogger.log("❌ Receive error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.lastError   = error.localizedDescription
                    self.isConnected = false
                }
                self.webSocket = nil
                self.session   = nil
                self.pingTimer?.invalidate()
                self.pingTimer = nil
            }
        }
    }

    // MARK: - Send

    func sendCommand(_ command: [String: Any]) {
        guard let webSocket = webSocket else {
            AppLogger.log("⚠️ Command dropped — not connected")
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: command)
            webSocket.send(.data(jsonData)) { [weak self] error in
                if let error = error {
                    AppLogger.log("❌ Send error: \(error.localizedDescription)")
                    DispatchQueue.main.async { self?.lastError = error.localizedDescription }
                }
            }
        } catch {
            AppLogger.log("❌ JSON encode error: \(error)")
        }
    }

    // MARK: - Message handling

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .data(let d):   data = d
        case .string(let s): data = s.data(using: .utf8)
        @unknown default:    data = nil
        }
        guard let data = data else { return }
        handleData(data)
    }

    private func handleData(_ data: Data) {
        do {
            let telemetry = try JSONDecoder().decode(TelemetryMessage.self, from: data)
            guard telemetry.type == "telemetry" else { return }
            DispatchQueue.main.async {
                self.onTelemetryReceived?(telemetry)
            }
        } catch {
            // Log the raw string for debugging when decode fails
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
            AppLogger.log("❌ JSON decode error: \(error)\n   raw: \(preview)")
        }
    }

    // MARK: - Ping

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.webSocket?.sendPing { error in
                if let error = error {
                    AppLogger.log("💔 Ping failed: \(error.localizedDescription)")
                    DispatchQueue.main.async { self?.isConnected = false }
                    self?.webSocket = nil
                    self?.session   = nil
                    self?.pingTimer?.invalidate()
                    self?.pingTimer = nil
                }
            }
        }
    }

    // MARK: - Command helpers

    func setController(name: String, enabled: Bool) {
        AppLogger.log("🎛️ setController \(name) → \(enabled ? "ON" : "OFF")")
        sendCommand(["type": "set_controller", "controller": name, "enabled": enabled])
    }

    func savePID() {
        AppLogger.log("💾 Saving PID config to robot")
        sendCommand(["type": "save_pid"])
    }

    func setPID(controller: String, kp: Float, ki: Float, kd: Float) {
        AppLogger.log("🔧 setPID \(controller)  Kp=\(kp) Ki=\(ki) Kd=\(kd)")
        sendCommand(["type": "set_pid", "controller": controller, "kp": kp, "ki": ki, "kd": kd])
    }

    func zeroIMU() {
        AppLogger.log("🎯 Zeroing IMU")
        sendCommand(["type": "zero_imu"])
    }

    func setArmed(_ armed: Bool) {
        AppLogger.log(armed ? "🔫 ARMING robot" : "🛑 DISARMING robot")
        sendCommand(["type": "arm", "value": armed])
    }

    func setMode(_ mode: Int) {
        AppLogger.log("🤖 setMode → \(mode)")
        sendCommand(["type": "set_mode", "value": mode])
    }

    func setTelemetry(encoders: Bool? = nil, imuFull: Bool? = nil, pidStates: Bool? = nil) {
        var command: [String: Any] = ["type": "set_telemetry"]
        if let v = encoders  { command["encoders"]   = v }
        if let v = imuFull   { command["imu_full"]   = v }
        if let v = pidStates { command["pid_states"] = v }
        AppLogger.log("📡 setTelemetry \(command.filter { $0.key != "type" })")
        sendCommand(command)
    }
}
