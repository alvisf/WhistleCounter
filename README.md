# WhistleCounter

iOS app that counts pressure cooker whistles using on-device DSP.

## Stack

- Swift 5.10, SwiftUI, iOS 17+
- `AVAudioEngine` for mic input
- `Accelerate` / `vDSP` for real-time FFT
- Strict concurrency (Swift 6 mode)
- `xcodegen` to generate the Xcode project from `project.yml`

## How detection works

The DSP detector (`DSPWhistleDetector`) taps the mic, runs a windowed FFT on
each 1024-sample buffer, and computes the ratio of signal energy in the
**2–4 kHz whistle band** versus total spectrum energy.

That ratio is fed into `WhistleGate`, a pure state machine that fires a
detection only when:

- ratio ≥ threshold (controlled by the sensitivity slider)
- sustained for ≥ 300 ms (filters clicks/pops)
- at least 1.5 s has passed since the last fire (prevents a single
  long whistle from being counted twice)

`WhistleGate` is split out from the audio pipeline so it can be
unit-tested without real audio — see `WhistleGateTests`.

## Swap the detector

`WhistleDetector` is a protocol. A future `SoundAnalysisWhistleDetector`
using Core ML's `SoundAnalysis` framework can be dropped in without
touching `WhistleSession` or the views.

## Build

```bash
# Regenerate the Xcode project after editing project.yml
xcodegen generate

# Build for simulator
xcodebuild -project WhistleCounter.xcodeproj \
  -scheme WhistleCounter \
  -destination 'generic/platform=iOS Simulator' \
  build

# Run tests
xcodebuild -project WhistleCounter.xcodeproj \
  -scheme WhistleCounter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Or just open `WhistleCounter.xcodeproj` in Xcode after `xcodegen generate`.

## On-device considerations

- Microphone permission prompt is triggered on first Start tap
  (`NSMicrophoneUsageDescription` in `Info.plist`).
- The audio session uses `.measurement` mode, which disables AGC /
  echo cancellation — we want the raw signal for DSP.
- Background audio is not yet enabled; stopping the app stops counting.
  To support "counter keeps going while phone is locked," add the
  `audio` background mode and test battery impact.
