# Screenshots

The repo ships with two screenshots of the Counter tab (light + dark). The
remaining screenshots (Recipes tab, History tab, Alarm sound picker) need
to be captured manually because macOS UI automation is blocked by
accessibility permissions.

## How to add the remaining screenshots

1. Boot the simulator and install the app:
   ```bash
   xcrun simctl boot A51E1950-7C79-40B7-BBD2-B9B2D64AA50E
   open -a Simulator
   xcodebuild -project WhistleCounter.xcodeproj \
     -scheme WhistleCounter \
     -destination 'platform=iOS Simulator,id=A51E1950-7C79-40B7-BBD2-B9B2D64AA50E' \
     -configuration Debug \
     -derivedDataPath build \
     build
   xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/WhistleCounter.app
   xcrun simctl launch booted com.alvisf.WhistleCounter
   ```
2. Tap through each tab you want to capture.
3. In the Simulator app, **File → Save Screen (⌘S)** saves a PNG to
   `~/Desktop`. Rename and move to `docs/screenshots/` following the
   naming convention below.

## Naming convention

| File | Contents |
|---|---|
| `01-counter-light.png` | Counter tab, light appearance (ships with repo) |
| `01-counter-dark.png`  | Counter tab, dark appearance (ships with repo) |
| `02-recipes.png`       | Recipes tab, light appearance |
| `03-history.png`       | History tab with at least one saved session |
| `04-alarm-picker.png`  | Counter → Alarm sound picker |
| `05-recipe-edit.png`   | New/edit recipe sheet |
