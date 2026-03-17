import Foundation

/// Main robot state model
struct RobotState: Codable {
    var battery: Float = 0.0
    var armed: Bool = false
    var mode: RobotMode = .balance
    var loopHz: Float = 0.0
    var thetaOffset: Float = 0.0
    var battVoltage: Float? = nil
    var battStatus: Int? = nil
    
    var imu: IMUData = IMUData()
    var encoders: EncoderData?
    var cat: CatData?
    
    var d1Balance: PIDState = PIDState()
    var d2Drive: PIDState = PIDState()
    var d3Steering: PIDState = PIDState()
    
    var motors: MotorData?
    
    enum CodingKeys: String, CodingKey {
        case battery, armed, mode
        case loopHz = "loop_hz"
        case imu, encoders, cat
        case d1Balance = "D1_balance"
        case d2Drive = "D2_drive"
        case d3Steering = "D3_steering"
        case motors
    }
}

enum RobotMode: Int, Codable {
    case idle     = 0
    case balance  = 1
    case extInput = 2
    case manual   = 3
}

/// IMU attitude data
struct IMUData: Codable {
    // Raw JSON fields from telemetry.c
    var theta: Float = 0.0      // = TB_ROLL_Y  (balance pitch, rotation about Y)
    var phi:   Float = 0.0      // = TB_PITCH_X (yaw/turning, rotation about X)
    var psi:   Float = 0.0      // = TB_YAW_Z   (side roll, rotation about Z)
    var thetaDot: Float = 0.0
    var phiDot:   Float = 0.0
    var psiDot:   Float = 0.0

    // Named aliases — use these in the UI so the mapping is explicit
    var tbRollY:  Float = 0.0
    var tbPitchX: Float = 0.0
    var tbYawZ:   Float = 0.0

    var qw: Float? = nil
    var qx: Float? = nil
    var qy: Float? = nil
    var qz: Float? = nil

    var accelX: Float?
    var accelY: Float?
    var accelZ: Float?
    var gyroX: Float?
    var gyroY: Float?
    var gyroZ: Float?

    enum CodingKeys: String, CodingKey {
        case theta, phi, psi
        case thetaDot = "theta_dot"
        case phiDot = "phi_dot"
        case psiDot = "psi_dot"
        case qw, qx, qy, qz
        case accelX = "accel_x"
        case accelY = "accel_y"
        case accelZ = "accel_z"
        case gyroX = "gyro_x"
        case gyroY = "gyro_y"
        case gyroZ = "gyro_z"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theta    = try c.decode(Float.self, forKey: .theta)
        phi      = try c.decode(Float.self, forKey: .phi)
        psi      = try c.decode(Float.self, forKey: .psi)
        thetaDot = try c.decode(Float.self, forKey: .thetaDot)
        phiDot   = try c.decode(Float.self, forKey: .phiDot)
        psiDot   = try c.decode(Float.self, forKey: .psiDot)
        qw       = try c.decodeIfPresent(Float.self, forKey: .qw)
        qx       = try c.decodeIfPresent(Float.self, forKey: .qx)
        qy       = try c.decodeIfPresent(Float.self, forKey: .qy)
        qz       = try c.decodeIfPresent(Float.self, forKey: .qz)
        accelX   = try c.decodeIfPresent(Float.self, forKey: .accelX)
        accelY   = try c.decodeIfPresent(Float.self, forKey: .accelY)
        accelZ   = try c.decodeIfPresent(Float.self, forKey: .accelZ)
        gyroX    = try c.decodeIfPresent(Float.self, forKey: .gyroX)
        gyroY    = try c.decodeIfPresent(Float.self, forKey: .gyroY)
        gyroZ    = try c.decodeIfPresent(Float.self, forKey: .gyroZ)
        // telemetry.c sends: theta=TB_ROLL_Y, phi=TB_PITCH_X, psi=TB_YAW_Z
        tbRollY  = theta
        tbPitchX = phi
        tbYawZ   = psi
    }

    init() {}
}

/// Encoder data
/// NOTE: JSON keys are "left_rad"/"right_rad"/"left_vel"/"right_vel" (legacy names),
/// but firmware now sends degrees and deg/s — Swift names reflect the true units.
struct EncoderData: Codable {
    var leftTicks: Int = 0
    var rightTicks: Int = 0
    var leftDeg: Float = 0.0
    var rightDeg: Float = 0.0
    var leftDegPerSec: Float = 0.0
    var rightDegPerSec: Float = 0.0

    enum CodingKeys: String, CodingKey {
        case leftTicks = "left_ticks"
        case rightTicks = "right_ticks"
        case leftDeg = "left_rad"        // firmware key kept for wire compat
        case rightDeg = "right_rad"
        case leftDegPerSec = "left_vel"
        case rightDegPerSec = "right_vel"
    }
}

/// Cat detection data
struct CatData: Codable {
    var detected: Bool = false
    var x: Float = 0.0
    var y: Float = 0.0
    var confidence: Float = 0.0
}

/// PID controller state
struct PIDState: Codable {
    var enabled: Bool = false
    var setpoint: Float = 0.0  // Make optional
    var measurement: Float? = nil
    var error: Float = 0.0
    var pTerm: Float?
    var iTerm: Float?
    var dTerm: Float?
    var output: Float = 0.0
    
    enum CodingKeys: String, CodingKey {
        case enabled, setpoint, measurement, error, output
        case pTerm = "p_term"
        case iTerm = "i_term"
        case dTerm = "d_term"
    }
}

/// Motor command data
struct MotorData: Codable {
    var leftDuty: Float = 0.0
    var rightDuty: Float = 0.0
    
    enum CodingKeys: String, CodingKey {
        case leftDuty = "left_duty"
        case rightDuty = "right_duty"
    }
}

/// Telemetry message from robot
struct TelemetryMessage: Codable {
    var type: String
    var timestamp: UInt64
    var system: SystemData?
    var imu: IMUData?
    var encoders: EncoderData?
    var cat: CatData?
    var d1Balance: PIDState?
    var d2Drive: PIDState?
    var d3Steering: PIDState?
    var motors: MotorData?
    
    enum CodingKeys: String, CodingKey {
        case type, timestamp, system, imu, encoders, cat, motors
        case d1Balance = "D1_balance"
        case d2Drive = "D2_drive"
        case d3Steering = "D3_steering"
    }
}

/// System status
struct SystemData: Codable {
    var battery: Float
    var armed: Bool
    var mode: Int
    var loopHz: Float
    var thetaOffset: Float = 0.0
    var battVoltage: Float?
    var battStatus: Int?

    enum CodingKeys: String, CodingKey {
        case battery, armed, mode
        case loopHz      = "loop_hz"
        case thetaOffset = "theta_offset"
        case battVoltage = "batt_voltage"
        case battStatus  = "batt_status"
    }
}
