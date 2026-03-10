import Foundation

/// PID configuration for one controller
struct PIDConfig: Codable, Identifiable {
    var id = UUID()
    var name: String
    var kp: Float
    var ki: Float
    var kd: Float
    var enabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case name, kp, ki, kd, enabled
    }
}

/// Complete robot PID configuration
struct RobotPIDConfig {
    var d1Balance: PIDConfig
    var d2Drive: PIDConfig
    var d3Steering: PIDConfig
    
    init() {
        d1Balance = PIDConfig(name: "D1: Balance", kp: 40.0, ki: 0.0, kd: 5.0, enabled: true)
        d2Drive = PIDConfig(name: "D2: Drive", kp: 20.0, ki: 0.5, kd: 2.0, enabled: false)
        d3Steering = PIDConfig(name: "D3: Steering", kp: 15.0, ki: 0.0, kd: 1.5, enabled: true)
    }
}
