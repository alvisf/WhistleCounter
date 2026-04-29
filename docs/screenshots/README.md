# Screenshots

The repo ships with screenshots of the three main tabs (Counter, Recipes,
History) plus a dark-mode Counter. These are regenerated from the iOS
simulator using a mix of `xcrun simctl io screenshot` and `cliclick`
for programmatic tapping.

## How to regenerate

```bash
# macOS + cliclick required
brew install cliclick

# Ensure the app is installed and the simulator is booted
xcrun simctl boot A51E1950-7C79-40B7-BBD2-B9B2D64AA50E   # or your device id
open -a Simulator
xcrun simctl launch booted com.alvisf.WhistleCounter

# Counter — light + dark
xcrun simctl ui booted appearance light
xcrun simctl io booted screenshot docs/screenshots/01-counter-light.png
xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot docs/screenshots/01-counter-dark.png

# Tap the Recipes tab (coords depend on your simulator window position)
# Find the Simulator window bounds:
#   osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of window 1'
# Tab bar is ~80px from the bottom, Recipes is the middle tab.
cliclick c:1852,1158  # adjust x/y for your setup
xcrun simctl io booted screenshot docs/screenshots/02-recipes-light.png

# History tab — right side of the tab bar
cliclick c:2004,1158
xcrun simctl io booted screenshot docs/screenshots/03-history-light.png
```

## Files

| File | Contents |
|---|---|
| `01-counter-light.png` | Counter tab, light appearance |
| `01-counter-dark.png`  | Counter tab, dark appearance |
| `02-recipes-light.png` | Recipes tab with seeded recipes |
| `03-history-light.png` | History tab (empty-state or populated) |
