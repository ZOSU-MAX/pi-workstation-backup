---
name: game-autopilot
description: "Autonomous game vehicle control via screen capture + PID."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Game-Automation, PID-Control, Computer-Vision, Autopilot, Input-Injection]
    related_skills: [opencode, python-debugpy]
---

# Game Vehicle Autopilot via Vision + PID

Autonomous bot that reads the game screen (HUD), computes control
inputs via PID loops, and injects them back into the game. For vehicles
(helicopters, planes, cars) where no API/memory access exists.

## When to Use

- Game has no mod API, no SDK, no memory-readable state
- User wants autonomous flight/driving in a specific game
- Bot must run alongside the game on the same or a networked PC
- Control is via keyboard/mouse/joystick only

## Architecture (Always This Shape)

```
Screen Capture → HUD Parser → State Estimator → Flight Controller → Input Injector
   (mss)          (PIL/tesseract)   (low-pass)        (cascaded PID)    (vgamepad/PWM)
```

## Procedure

### Phase 0: Reconnaissance
1. Screenshot the game HUD. Identify: altitude, speed, heading, attitude indicators.
2. Note screen positions (x, y, w, h) for each element. These go in a YAML config.
3. Determine control axes and their input types (analog vs digital).
4. Check for anti-cheat: if present, prefer vgamepad over SendInput.

### Phase 1: HUD Parser
1. Write region-based parser: capture each HUD element, extract value.
2. For numeric displays: OCR with tesseract (upscale, threshold, whitelist digits).
3. For bar indicators: color mask → fill ratio → mapped value.
4. For attitude: horizon line detection → pitch/roll angles.
5. Export a `parse_full_frame()` function returning a typed state dict.
6. Include a calibration mode (`--calibrate`) to adjust regions visually.

### Phase 2: PID Controller
1. Implement cascaded PID: outer (position error → rate command) → inner (rate error → actuator).
2. Each axis gets its own PID instance with independent gains.
3. Critical: outer loop `output_limit` must be large enough for the commanded rate (e.g., altitude PID output_limit must allow ±8 m/s, not ±1).
4. Add integral anti-windup (clamp integral when output saturates).
5. Tune on a simulator first, then refine in-game.

### Phase 3: Input Injection
1. For analog axes (pitch/roll): vgamepad virtual joystick.
2. For digital axes (collective/yaw on keybed): PWM duty cycle at 20Hz.
3. PWM formula: press_time = duty * period; alternate press/release within each cycle.
4. Always provide emergency stop (release all keys + zero all axes).

### Phase 4: State Machine
1. Define states: IDLE → TAKEOFF → HOVER → NAVIGATE → LAND → IDLE (plus EMERGENCY).
2. Each state computes its own target (altitude, heading, speed) for the PID controller.
3. Transitions triggered by conditions (altitude reached, waypoint proximity, timer).
4. Emergency state: zero all controls or execute recovery (level out + gentle descent).

### Phase 5: Mission Logic
1. Waypoint navigation: bearing/distance from current position to next WP.
2. Hover handling: when arrived AND hovering, return ZERO speed target (not WP coordinates — causes oscillation).
3. Slow down for large heading errors (>30° → 30% speed).
4. Landing: descent profile (altitude → max descent rate mapping).

### Phase 6: Game Mode Integration
1. Write a `game_mode.py` that loops: `capture_screen() → parse_hud() → fsm.update() → injector.send()`.
2. The HUD parser's `parse_full_frame()` returns a dict; convert to `HelicopterState` before feeding the controller.
3. Start with simple altitude-hold (P-controller on altitude → collective), then add full FSM.
4. Run at 20Hz (50ms loop); skip frames rather than blocking.

### Phase 7: Real-Game Testing
1. Write a synthetic simulator first — catches control logic bugs without the game.
2. On the target machine: install deps, run `debug_hud.py` to verify HUD region alignment.
3. Calibrate in Firing Range / sandbox before multiplayer.
4. Test input direction on the simulator first — inverted axes cause flyaway.
5. If the HUD parse returns all zeros/defaults, the region coordinates don't match the actual game UI — use `debug_hud.py` to diagnose.

## Pitfalls

- **PID output_limit too small**: If the outer loop's output_limit is 1.0 but you need to command 8 m/s climb rate, the controller saturates and never reaches target. Set output_limit to the max physically achievable rate, not 1.0.
- **Speed sign inversion**: In many games, positive pitch = nose up = slow down. If the speed PID outputs positive for "need more speed," you must negate it before applying. Verify direction on the simulator first.
- **Hover oscillation**: After arriving at a waypoint, the navigator must return speed=0 and current heading as targets. Returning the waypoint's coordinates as target causes the helicopter to keep "flying to" a point it's already at, inducing drift/oscillation.
- **Heading overshoot at high speed**: Flying fast into a turn causes overshoot. Reduce cruise speed proportional to heading error (>30° error → 30% speed).
- **PWM resolution**: A 20Hz PWM period gives only 50ms resolution. Fast-reacting controls (yaw) may feel stepped. Increase to 40-50Hz if the game accepts it, but higher frequencies risk key-state desync.
- **Anti-cheat detection**: SendInput and vgamepad can trigger anti-cheat. Test first in single-player/sandbox. If blocked, use a hardware solution (Arduino/Teensy as USB joystick).
- **HUD region drift**: Screen resolution changes, UI scaling, and windowed mode shift HUD positions. Always make regions configurable via YAML and provide a calibration mode.
- **HUD reads all zeros**: If `parse_full_frame()` returns all defaults (0.0, None), the region coordinates don't match the actual game UI. Run `debug_hud.py` to save a screenshot and print each region's color statistics — compare the saved image against the configured x,y,w,h to find the real positions.
- **Resolution mismatch**: HUD region coordinates are resolution-specific. A config written for 1920x1080 will NOT work on 2560x1440 — the scale factor is 1.333x in both dimensions. Always check the actual game resolution (from the screenshot's shape) and scale all coordinates accordingly, or write a resolution-specific config file. The debug script prints the detected resolution; compare it against the config's assumed resolution.
- **mss ScreenShot not subscriptable**: `mss.grab()` returns a `ScreenShot` object, not a numpy array. You must convert it first: `np.array(img, dtype=np.uint8)[:, :, :3]`. Slicing `img[:, :, :3]` directly raises `TypeError: 'ScreenShot' object is not subscriptable`.
- **Missing numpy import in capture module**: If `capture/__init__.py` uses `np.array()` in `capture_full()` but only has `from __future__ import annotations`, you get `NameError: name 'np' is not defined`. Always add `import numpy as np` at the top.
- **Takeoff climb stall**: If the takeoff controller feeds incremental altitude targets (current + small step) to the FlightController, the PID sees only a tiny error each cycle and never commands meaningful climb rate. Set the final cruise target immediately and let the PID ramp up.
- **File transfer from Pi container**: If the Pi runs in a Docker container with bind-mount at `/home/jian/.hermes`, SCP files via the bind-mount path (e.g., `/home/jian/.hermes/project.tar.gz`), not `/tmp` (which is container-only and invisible to the host).
- **Cross-platform workflow**: When developing on a headless Pi but targeting a Windows game machine: (1) Build and test the simulator on the Pi, (2) Package with `tar czf /opt/data/project.tar.gz -C <dir> <name>`, (3) SCP via the bind-mount path, (4) On Windows: extract, run `debug_hud.py` for HUD calibration, (5) Then run `game_mode.py` for live testing. The two-machine iteration loop is: edit on Pi → repackage → SCP → test on Windows → report results → repeat.

## Rules

1. Always build and test a synthetic simulator first — it catches control logic bugs without needing the game running.
2. Use cascaded PID (outer position → inner rate → actuator) for any vehicle with momentum.
3. Make HUD regions and PID gains configurable files, not hardcoded constants.
4. Provide emergency stop on every control path.
5. Test input direction on the simulator before real-game testing — inverted axes are the #1 cause of flyaway.
