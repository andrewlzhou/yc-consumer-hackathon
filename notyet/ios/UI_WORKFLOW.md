# UI workflow (no backend needed)

`ScanAPI.baseURL` still says YOUR-DEPLOYMENT, so the whole app runs on sample data:
History has 3 items, Home opens the Wait report, Search returns a mock verdict after a short "Digging…".

## Build and look at it from the terminal (Claude Code or Codex can run these)

```bash
# list simulators if the name below doesn't exist
xcrun simctl list devices available | grep iPhone

xcodebuild -project NotYetUI.xcodeproj -scheme NotYetUI \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build

xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; open -a Simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/NotYetUI.app

BUNDLE=com.yourname.notyetui   # your bundle ID
xcrun simctl launch --terminate-running-process booted $BUNDLE                      # Home
xcrun simctl launch --terminate-running-process booted $BUNDLE -startTab history    # History
xcrun simctl launch --terminate-running-process booted $BUNDLE -startTab search     # Search
xcrun simctl launch --terminate-running-process booted $BUNDLE -startTab account    # Account
xcrun simctl openurl booted notyet://scan/a   # Wait report
xcrun simctl openurl booted notyet://scan/b   # Fake deal report
xcrun simctl openurl booted notyet://scan/c   # Buy report
xcrun simctl io booted screenshot shots/history.png
```

Sketches to match are in `sketches/`.

## Rules for every change
- Black background, white text, Prussian blue (#003153) through `Theme` tokens only.
- Square corners. No RoundedRectangle, Capsule or Circle in Views/.
- As little text as possible. No explanations where a label or number does the job.
- Only edit `Views/` (and `App/SampleData.swift` for more sample states). Don't change `Models.swift`
  or the function signatures in `ScanAPI.swift`: the backend and the integrator depend on them.
