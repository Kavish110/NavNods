# NodNav

Hands-free Mac navigation with your AirPods. NodNav is a macOS menu bar app that reads head motion from AirPods and turns deliberate head gestures into scrolling, desktop switching, and browser navigation.

Motion data is processed locally and never leaves your Mac.

## Gestures

| Head movement | Action | Where |
| --- | --- | --- |
| Tilt down / up | Scroll down / up (speed grows with tilt) | Any app |
| Lean left, hold | Previous desktop (`⌃←`) | Anywhere |
| Lean right, hold | Next desktop (`⌃→`) | Anywhere |
| Quick turn left, then back to center | Back (`⌘[`) | Supported browsers |
| Quick turn right, then back to center | Forward (`⌘]`) | Supported browsers |

Back/forward only fire when the frontmost app is Safari, Chrome, Arc, Edge, Firefox, or Brave.

Gestures are suppressed while you're moving your whole body (walking, standing up), and the app pauses itself whenever your AirPods disconnect.

## Requirements

- macOS 14 or later
- AirPods with head tracking (AirPods Pro, AirPods Max, or AirPods 3rd generation or later)
- Xcode 26 or later to build
- **Accessibility permission**, so NodNav can post keyboard and scroll events
- **Motion & Fitness permission**, so NodNav can read headphone motion

Desktop switching uses the system "Move left/right a space" shortcuts. Make sure they're enabled under **System Settings → Keyboard → Keyboard Shortcuts → Mission Control**.

## Getting started

1. Open `NavNods.xcodeproj` in Xcode.
2. Select the **NodNav** scheme and run (`⌘R`).
3. Grant Accessibility access when prompted (**System Settings → Privacy & Security → Accessibility**). If you rebuild and gestures stop working, remove and re-add the app there.
4. Put in your AirPods. The menu bar icon's status changes to "Tracking AirPods" once motion starts streaming.
5. Sit in a comfortable neutral position and click **Recalibrate**.

NodNav runs as a menu bar app only. It has no Dock icon.

## Using the menu bar app

- **Pitch / Yaw / Roll**: your current head pose relative to neutral.
- **Last action**: the most recent gesture NodNav acted on.
- **Motion source**: switch between live AirPods and two simulated traces (lean, scroll). Simulated sources drive the display and gesture recognition but never post real events, so they're safe for testing.
- **Head Movement Monitor…**: opens a window with a live 3D head preview and a **Sensitivity** slider (0.25× to 3×).
- **Pause / Resume**: stops all actions without quitting.
- **Recalibrate**: sets your current head position as the new neutral.

NodNav also slowly re-centers neutral on its own when your head has been still for a few seconds, which absorbs gradual posture drift.

## How it works

```text
AirPods (CoreMotion)
  → MotionSource            HeadphoneMotionSource / SimulatedMotionSource
  → PoseProcessor           calibration, One Euro filtering, body-motion gate
  → Gesture machines        lean, turn (discrete) + ScrollModeController (continuous)
  → GestureArbiter          resolves gestures that confirm within 150 ms of each other
  → ActionRouter            pause state, per-app rules (e.g. browsers only)
  → ActionEngine            posts CGEvents (keys, scroll wheel)
```

Pose filtering and gesture recognition run off the main thread inside the `GesturePipeline` actor. Everything that touches UI or posts events runs on the main actor.

### Project layout

| Folder | Contents |
| --- | --- |
| `App/` | App entry point, menu bar UI, Head Movement window, pipeline coordinator, pause state |
| `Motion/` | Motion source protocol, AirPods source, simulated sources |
| `Pose/` | Calibration, relative pose math, One Euro filter |
| `Gestures/` | Gesture state machines, arbiter, scroll controller, pipeline actor |
| `Actions/` | Action router and engine, frontmost-app context, Accessibility helper, call adapter scaffolding |
| `Settings/` | Gesture thresholds, persisted to `UserDefaults` |

## Tuning

Default thresholds live in `GestureThresholds` (`Settings/GestureSettings.swift`):

| Setting | Default |
| --- | --- |
| Lean angle / hold time | 15° / 0.3 s |
| Turn angle / return-to-center angle / return window | 20° / 7° / 0.6 s |
| Cooldown between gestures | 0.7 s |
| Scroll dead zone / max tilt | 10° / 35° |
| Scroll speed range | 40 to 1,200 px/s |
| Body-motion gate | 0.3 g |

Thresholds are saved to `UserDefaults` under `gestureThresholds.v1`. There's no settings UI for them yet.

## Tests

Tests use Swift Testing and live in `MyAppTests/`. Run them in Xcode with `⌘U`.

## Distribution

NodNav needs Accessibility trust and runs with the App Sandbox disabled so it can post system-wide input events. That makes it incompatible with the Mac App Store. Distribute it directly, signed and notarized.

## Roadmap

- Nod and shake gestures
- Answering and declining calls (the `CallAdapter` scaffolding is in place, but no adapters exist yet)
- Per-app gesture rules
- A settings UI for gesture thresholds
