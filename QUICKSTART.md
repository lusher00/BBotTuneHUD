# iPhone App - Quick Start

## 5-Minute Setup

### 1. Create Xcode Project (2 min)

```
Xcode → New → Project
  Template: iOS App
  Name: CatFollowerApp
  Interface: SwiftUI
  Language: Swift
```

### 2. Create Folders (30 sec)

Right-click `CatFollowerApp` folder, create groups:
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

**Views/**
- ContentView.swift (replace existing)
- ControlView.swift
- PIDTuningView.swift
- IMUVisualizationView.swift
- DebugView.swift
- SettingsView.swift

**Root/**
- Info.plist (replace existing)
- CatFollowerApp.swift (already exists, verify)

### 4. Build & Run (30 sec)

```
⌘B (Build)
⌘R (Run)
```

## First Run

1. App launches → Go to **Settings** tab
2. Enter IPs:
   - BeagleBone: `192.168.1.100`
   - RPi5: `192.168.1.139`
3. Tap **Reconnect**
4. Go to **Control** tab
5. You should see:
   - ✅ "Connected" indicator
   - ✅ Video stream
   - ✅ Live telemetry

## Testing

### Test ARM/DISARM
1. Place robot on floor
2. Tap **ARM** button (green)
3. Robot should try to balance
4. Tap **DISARM** (red) to stop

### Test PID Tuning
1. Go to **PID Tuning** tab
2. Select "D1: Balance"
3. Adjust Kp slider
4. See "Live Status" update
5. Robot behavior changes in real-time

### Test 3D Visualization
1. Go to **3D IMU** tab
2. Tilt robot
3. 3D model should tilt in sync
4. Drag to rotate view

### Test Cat Following
1. Go to **Control** tab
2. Select mode: **Follow Cat**
3. Place cat in view of camera
4. Should see "Cat Detected" status
5. Robot should track cat

## Troubleshooting

**No connection:**
```
Settings → Check IPs → Tap Reconnect
```

**No video:**
```
Settings → Check RPi5 IP
Safari: http://192.168.1.139:5000
```

**Build errors:**
```
Clean: ⇧⌘K
Build: ⌘B
```

## Done! 🎉

Your iPhone app is complete and working!

**Features:**
- ✅ Real-time video
- ✅ Live telemetry
- ✅ PID tuning
- ✅ 3D visualization
- ✅ Cat tracking
- ✅ Debug console

**Total setup time:** ~5 minutes
