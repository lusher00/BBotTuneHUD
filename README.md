# BBotTuneHUD

iPhone companion app for the balance_bot self-balancing robot. Streams live telemetry, tunes PID gains in real time, visualizes IMU orientation in 3D, and provides full arm/disarm control — all over WebSocket.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey?logo=apple)
![Language](https://img.shields.io/badge/language-Swift%205.9-orange?logo=swift)
![Framework](https://img.shields.io/badge/framework-SwiftUI-blue)

---

## Features

- **Live telemetry** — battery voltage, armed state, control loop frequency, PID states, encoder positions
- **3D IMU visualization** — SceneKit cube driven by pitch/roll/yaw angles with smoothing and per-axis trim offsets
- **Live PID tuning** — adjust Kp/Ki/Kd for all three controllers and send to robot without restarting
- **Arm / Disarm** — with the same tilt-angle safety check as the hardware arm switch
- **In-app log console** — color-coded, timestamped, scrolling log of all WebSocket events
- **Auto-reconnect** — reconnects automatically if the robot reboots or the connection drops
- **No RC controller required** — full robot control from the app alone

---

## Screenshots

| Control | IMU | PID Tuning | Debug |
|---------|-----|------------|-------|
| Arm/disarm, mode, video | 3D attitude cube + angle readouts | Live gain sliders | Scrolling log + telemetry |

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   BBotTuneHUD (SwiftUI)              │
│                                                 │
│  ContentView (TabView)                          │
│  ├── ControlView       — arm, mode, video feed  │
│  ├── PIDTuningView     — gain sliders, send     │
│  ├── IMUVisualizationView — SceneKit 3D cube    │
│  ├── XboxStatusView    — RC channel display     │
│  ├── DebugView         — log console + telemetry│
│  └── SettingsView      — IP config, reconnect   │
│                                                 │
│  RobotViewModel (@StateObject)                  │
│  └── WebSocketService  — send/receive JSON      │
│  └── AppLogger         — thread-safe log buffer │
└────────────────────┬────────────────────────────┘
                     │ WebSocket ws://<beaglebone>:8675
              balance_bot robot
```

### Key Files

| File | Description |
|------|-------------|
| `Models/RobotState.swift` | Codable telemetry model — IMU, PID, encoders, motors |
| `Models/PIDConfig.swift` | Local PID gain state |
| `ViewModels/RobotViewModel.swift` | Published state, commands, IMU zero, auto-reconnect |
| `Services/WebSocketService.swift` | URLSessionWebSocketTask, receive loop, JSON send |
| `Services/AppLogger.swift` | Thread-safe singleton log buffer, max 500 entries |
| `Views/IMUVisualizationView.swift` | SceneKit cube, Euler-angle orientation, trim sliders |
| `Views/DebugView.swift` | Live log console + system telemetry |
| `Views/PIDTuningView.swift` | Gain sliders, controller enable toggles |
| `Views/ControlView.swift` | Arm/disarm, mode selector, video stream |

---

## Telemetry Protocol

The app connects to the Node.js WebSocket bridge running on the BeagleBone at port 8675. All messages are JSON.

### Incoming (robot → app)

```json
{
  "type": "telemetry",
  "timestamp": 1234567890,
  "system": { "battery": 11.8, "armed": false, "mode": 1, "loop_hz": 100.0 },
  "imu": {
    "theta": 0.021, "phi": -0.003, "psi": 0.14,
    "theta_dot": 0.001, "phi_dot": 0.0, "psi_dot": -0.002,
    "qw": 0.9998, "qx": 0.011, "qy": -0.002, "qz": 0.07
  },
  "D1_balance": { "enabled": true, "setpoint": 0.0, "measurement": 0.021, "error": -0.021, "output": -0.84 },
  "encoders": { "left_ticks": 142, "right_ticks": 139, "left_vel": 0.12, "right_vel": 0.11 }
}
```

### Outgoing (app → robot)

```json
{ "type": "arm", "value": true }
{ "type": "set_mode", "value": 1 }
{ "type": "set_pid", "controller": "D1_balance", "kp": 40.0, "ki": 0.0, "kd": 5.0 }
{ "type": "set_controller", "controller": "D1_balance", "enabled": true }
{ "type": "set_telemetry", "encoders": true, "pid_states": true }
```

---

## IMU Visualization

The 3D cube is driven directly by the robot's `theta` (pitch), `phi` (roll), and `psi` (yaw) angles — the same values the PID controller acts on. No quaternion path is used, avoiding any dependency on the optional quaternion telemetry fields.

Orientation is composed as intrinsic YXZ:

```swift
let qYaw   = simd_quatf(angle: yaw,   axis: SIMD3(0, 1, 0))
let qPitch = simd_quatf(angle: pitch,  axis: SIMD3(1, 0, 0))
let qRoll  = simd_quatf(angle: roll,   axis: SIMD3(0, 0, 1))
let target = simd_normalize(qYaw * qPitch * qRoll)
node.simdOrientation = simd_slerp(node.simdOrientation, target, smoothing)
```

A **Zero display** button captures the current resting angles as trim offsets, so the cube sits level when the robot is balanced upright regardless of IMU mounting orientation.

---

## Setup

### Requirements

- Xcode 15+
- iOS 17+ deployment target
- A running balance_bot with the Node.js WebSocket bridge

### Project Structure

```
BBotTuneHUD/
├── Models/
│   ├── RobotState.swift
│   └── PIDConfig.swift
├── ViewModels/
│   └── RobotViewModel.swift
├── Services/
│   ├── WebSocketService.swift
│   └── AppLogger.swift
└── Views/
    ├── ContentView.swift
    ├── ControlView.swift
    ├── PIDTuningView.swift
    ├── IMUVisualizationView.swift
    ├── XboxStatusView.swift
    ├── DebugView.swift
    └── SettingsView.swift
```

### Building

1. Clone the repo and open `BBotTuneHUD.xcodeproj` in Xcode
2. Set your development team in project settings
3. Build and run on device (`⌘R`)

### Connecting

1. Open app → **Settings** tab
2. Enter BeagleBone IP address
3. Tap **Reconnect** (or wait for auto-connect)
4. Green indicator = connected, telemetry flowing

---

## Tuning Without an RC Controller

The app provides full robot control when no transmitter is available:

1. Place robot upright on flat ground
2. **IMU tab** → tap **Zero display at current angles**
3. **Control tab** → tap **ARM**
   - Arm is rejected if lean angle exceeds ~14° for safety
4. Robot attempts to balance
5. **PID tab** → increase Kp until oscillation, reduce, add Kd to damp
6. Tap **DISARM** before it falls
7. Iterate

---

## Related

- [balance_bot](https://github.com/yourusername/balance_bot) — BeagleBone Blue C firmware and Node.js bridge

---

## License

MIT
