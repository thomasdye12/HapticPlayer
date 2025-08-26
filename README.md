# Haptic Video Sync (UIKit + SwiftUI)

Play an HLS or local video **in lockstep** with an Apple **Core Haptics** `.ahap` pattern — all with the **native AVPlayerViewController controls** (play/pause/seek/scrub). Includes a SwiftUI grid to launch multiple clips and simple CLI tools to convert a TSV/CSV timeline into AHAP.

---

## 🎥 Watch the video: How I figured it out

I walk through the entire approach — parsing `.ahap`, syncing to `AVPlayer`, drift correction, and edge cases.

**▶️ Watch here:** **[https://youtu.be/g6TUiQzcwac](https://youtu.be/g6TUiQzcwac)**

> Replace `VIDEO_ID` above with your actual YouTube ID.  
> Optional thumbnail embed:
>
> `[![Watch the video](https://img.youtube.com/vi/g6TUiQzcwac/maxresdefault.jpg)](https://youtu.be/g6TUiQzcwac)`

---

## Features

- ✅ Uses **AVPlayerViewController**’s built-in UI (no custom buttons)
- ✅ Syncs haptics on **Play / Pause / Seek / Scrub / Time Jump / Stall / End**
- ✅ Light **periodic re-pin** (defaults to ~300ms) to prevent drift
- ✅ Works with **remote** and **bundled** `.ahap` files
- ✅ SwiftUI **grid** to browse and launch clips
- ✅ Simple **TSV/CSV → AHAP** converters (PHP or Bash+awk+jq)

---

## Requirements

- iOS 14+ (iOS 15+ recommended)
- **Real device** (Simulator doesn’t do Core Haptics)
- **Settings → Sounds & Haptics → System Haptics** = ON
- HTTPS access for remote HLS/AHAP

---

## How it works (high level)

- **Clock of truth:** `AVPlayer` time
- **Haptics:** `CHHapticEngine` + `CHHapticAdvancedPatternPlayer`
- **Sync strategy:**
  - Mirror player state with:
    - `player.timeControlStatus` (play/pause/waiting)
    - `AVPlayerItemTimeJumped`, `AVPlayerItemPlaybackStalled`, `AVPlayerItemDidPlayToEndTime`
  - On each event: **seek** the haptics to `player.currentTime()` and **start/resume/pause** to match
  - During playback: periodically **re-pin** haptics to the video time (tiny nudge, drift-free)

> There’s no public haptic `currentTime`. We **don’t read** a haptic playhead; we **slave** haptics to video time instead.

---

## AHAP quickstart

An `.ahap` is JSON with `Version` and a `Pattern` array of events/curves. Example:

```json
{
  "Version": 1,
  "Pattern": [
    {
      "Event": {
        "EventType": "HapticContinuous",
        "Time": 2.0,
        "EventDuration": 1.0,
        "EventParameters": [
          { "ParameterID": "HapticIntensity", "ParameterValue": 0.6 },
          { "ParameterID": "HapticSharpness", "ParameterValue": 0.3 }
        ]
      }
    },
    {
      "ParameterCurve": {
        "ParameterID": "HapticIntensity",
        "Time": 2.0,
        "ParameterCurveControlPoints": [
          { "Time": 2.0, "ParameterValue": 0.2 },
          { "Time": 3.0, "ParameterValue": 0.9 }
        ]
      }
    }
  ]
}
```

HapticTransient = tap
HapticContinuous + EventDuration = rumble
All times in seconds; intensity/sharpness in 0…1.



More info is needed here but it is a baseline, hope you enjoy 


Thomas Dye 

