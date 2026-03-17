# BBotTuneHUD - Quick Start

## 5-Minute Setup

### 1. Create Xcode Project (2 min)

```
Xcode → New → Project
  Template: iOS App
  Name: BBotTuneHUD
  Interface: SwiftUI
  Language: Swift
```

### 2. Create Folders (30 sec)

Right-click `BBotTuneHUD` folder, create groups:
- Models
- Views
- ViewModels
- Services

### 3. Add Files (2 min)

Copy-paste these files into respective folders:

**Models/**
- RobotState.swift
- PIDConfig.swift

**ViewModels/**
- RobotViewModel.swift

**Services/**
- WebSocketService.swift
- AppLogger.swift

**Views/**
- ContentView.swift (replace existing)
- ControlView.swift
- PIDTuningView.swift
- IMUVisualizationView.swift
- XboxStatusView.swift
- DebugView.swift
- SettingsView.swift

**Root/**
- BBotTuneHUD.swift (already exists, verify)

### 4. Build & Run (30 sec)

```
⌘B (Build)
⌘R (Run)
```

---

## First Run

1. App launches → go to **Settings** tab
2. Enter BeagleBone IP: `192.168.1.100`
3. Tap **Reconnect**
4. Go to **Control** tab — you should see:
   - ✅ "Connected" indicator
   - ✅ Live telemetry (battery, loop Hz, armed state)

---

## Testing

### Arm / Disarm
1. Place robot upright on floor
2. Tap **ARM** — rejected if lean angle > ~14°
3. Robot attempts to balance
4. Tap **DISARM** to stop motors

> No RC controller needed — the app provides full arm/disarm control.

### PID Tuning
1. Go to **PID Tuning** tab
2. Select controller (D1: Balance, D3: Steering)
3. Adjust Kp/Ki/Kd sliders
4. Tap **Send** — gains update on robot immediately, no restart needed

### 3D IMU Visualization
1. Go to **IMU** tab
2. Tilt robot — 3D model tracks in sync
3. Tap **Zero display** to set current angles as level reference
4. Drag to orbit the view

### Debug Console
1. Go to **Debug** tab
2. Live color-coded log of all WebSocket events
3. Tap trash icon to clear
4. Toggle autoscroll as needed

### Object Tracking Mode
1. Go to **Control** tab
2. Select mode: **Follow**
3. Robot accepts position commands from external vision system over UART
4. Status shows tracking state

---

## Troubleshooting

**No connection:**
```
Settings → Check BeagleBone IP → Tap Reconnect
```

**Check balance_bot services on BeagleBone:**
```bash
systemctl status balance_bot
systemctl status balance_bot_server
```

**Build errors:**
```
Clean:  ⇧⌘K
Build:  ⌘B
```

**Too many apps on device (free developer account):**
```
Delete an old app from iPhone, then re-run
```

---

## Done! 🎉

**Features:**
- ✅ Live telemetry
- ✅ PID tuning
- ✅ 3D IMU visualization
- ✅ Debug console
- ✅ Arm / Disarm
- ✅ Object tracking mode
- ✅ Auto-reconnect