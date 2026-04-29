# WhistleCounter

An iOS app that counts pressure cooker whistles using on-device audio
detection. Set a target, tap start, and the app listens for whistles in
the 2–4 kHz band. When it hits your target it plays an alarm and
vibrates the phone so you can walk away from the stove.

Built in SwiftUI with `AVAudioEngine` + `vDSP` for real-time FFT. All
processing is on-device — no accounts, no cloud, no telemetry.

<p align="center">
  <img src="docs/screenshots/01-counter-light.png" width="260" alt="Counter tab (light)" />
  <img src="docs/screenshots/01-counter-dark.png"  width="260" alt="Counter tab (dark)" />
</p>

## Features

- **Automatic whistle detection** — FFT-based band-energy detector
  filters out clicks, dropouts, and amplitude wobbles so a single
  long whistle counts as one, not many.
- **Recipes** — built-in list of common dishes (rice, dal, rajma,
  curry, chickpeas, potatoes…) with whistle counts. Tap a recipe to
  apply it and start listening in one step. Add, edit, and delete
  your own recipes; "Restore defaults" brings back the seed list.
- **Per-recipe alarm sounds** — pick one of five system sounds
  (Tri-tone, Bell, Chime, Glass, Alert) as the global default, or
  override it per recipe. Two-second looping preview in the picker.
- **Session history** — every finished session is saved locally
  (count, duration, recipe name, date). Swipe-to-delete per row or
  "Clear all".
- **Looping alarm with haptics** — when the target is reached the
  phone plays the selected sound on a loop with heavy-impact haptics
  and overrides the silent switch, so you'll hear it from across the
  kitchen. Tap OK, Stop, or Reset to silence it.
- **Dark mode** — follows the system appearance with a dedicated
  dark app-icon variant.
- **Local-only storage** — recipes and history live in the app's
  sandbox as plain JSON. Uninstall = your data is gone.

## Requirements

- Xcode 16 or later
- iOS 18.0 or later on the device / simulator
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```bash
git clone https://github.com/alvisf/WhistleCounter.git
cd WhistleCounter

# Regenerate the .xcodeproj from project.yml
xcodegen generate

open WhistleCounter.xcodeproj
```

In Xcode: pick an iPhone simulator (iPhone 17 Pro works) or your
device, hit ⌘R. On first run you'll be asked for microphone
permission.

Or from the command line:

```bash
xcodebuild \
  -project WhistleCounter.xcodeproj \
  -scheme WhistleCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

## Test

```bash
xcodebuild \
  -project WhistleCounter.xcodeproj \
  -scheme WhistleCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

79 unit tests cover the DSP gate state machine, session state,
history/recipe stores, and alarm-sound routing.

## How detection works

The audio pipeline runs for every buffer the mic delivers:

1. Apply a Hann window to the latest 1024 samples.
2. Real-to-complex forward FFT via `vDSP`.
3. Compute the fraction of spectral power in the **2–4 kHz** band vs.
   total power. That ratio is the "whistle-ness" score.
4. Feed the score into a small state machine (`WhistleGate`) that
   decides when to fire a detection.

The gate has three states (`idle`, `pending`, `firing`) with
configurable thresholds. It only fires when the band-energy stays
above `fireRatio` for at least `minDurationSec`, and won't fire
again until the signal has been below a release threshold
(60% of the fire threshold — hysteresis) for at least
`minGapSec`. That combination ensures a single real whistle is
counted exactly once, even when its amplitude wobbles mid-whistle.

The DSP policy is pure Swift (no audio dependencies) so it's
directly unit-tested against synthetic energy-ratio streams.

## Project layout

```
WhistleCounter/
├── Audio/                  # WhistleDetector protocol + DSP detector
│                           # AlarmPlayer + system sound playback
├── Models/                 # WhistleSession, Recipe, SessionRecord
│   └── Stores/             # JSON-backed recipe + history stores
├── Views/
│   ├── Counter/            # Counter tab (big number + controls)
│   ├── Recipes/            # Recipes tab + edit sheet
│   ├── History/            # History tab
│   └── AlarmSoundPickerView.swift
├── Assets.xcassets/        # App icon (any/dark/tinted variants)
└── WhistleCounterApp.swift # App entry
Tools/
├── icon.html               # App icon rendered in CSS
└── generate-icons.sh       # Rasterizes to 1024×1024 PNGs via headless Chrome
```

## App icon

The icon is generated from `Tools/icon.html` and rasterized via
headless Chrome. To regenerate after editing the HTML:

```bash
bash Tools/generate-icons.sh
```

Output goes straight into `WhistleCounter/Assets.xcassets/AppIcon.appiconset/`.

## Status

Personal project — shared publicly for anyone who wants to read the
code or build it themselves. Not published on the App Store yet.

## License

MIT — see [LICENSE](LICENSE).
