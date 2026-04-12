import Foundation

/// Runtime-tunable parameters for the D2 position (hold/drive) controller.
/// Mirrors pos_config_t in balance_bot.h exactly.
struct PosConfig: Codable {
    var zoneA:          Int32 = 8000
    var zoneB:          Int32 = 4000
    var zoneC:          Int32 = 1000
    var scaleA:         Float = 600
    var scaleB:         Float = 800
    var scaleC:         Float = 1000
    var scaleD:         Float = 80
    var velScaleStop:   Float = 60
    var velScaleMove:   Float = 70
    var velScaleTurning:Float = 70
    var stoppedVel:     Int32 = 0
    var maxCorrection:  Float = 0.3
    var maxAngleRate:   Float = 0.05
    var backToSpot:     Int32 = 1   // 1 = full zone hold, 0 = loose

    enum CodingKeys: String, CodingKey {
        case zoneA          = "zone_a"
        case zoneB          = "zone_b"
        case zoneC          = "zone_c"
        case scaleA         = "scale_a"
        case scaleB         = "scale_b"
        case scaleC         = "scale_c"
        case scaleD         = "scale_d"
        case velScaleStop   = "vel_scale_stop"
        case velScaleMove   = "vel_scale_move"
        case velScaleTurning = "vel_scale_turning"
        case stoppedVel     = "stopped_vel"
        case maxCorrection  = "max_correction"
        case maxAngleRate   = "max_angle_rate"
        case backToSpot     = "back_to_spot"
    }
}
