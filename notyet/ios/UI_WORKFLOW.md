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
xcrun simctl openurl booted notyet://scan/d   # Look around report (CONSIDER_ALTERNATIVE, with alternatives)
xcrun simctl openurl booted notyet://scan/e   # Check first report (INVESTIGATE, low confidence, match note)
xcrun simctl openurl booted notyet://scan/digging   # loading state that never finishes
xcrun simctl launch --terminate-running-process booted $BUNDLE -demoLiveActivity YES                  # Live Activity: "Digging…" steps, Wait verdict after 6 s; swipe home to see the Dynamic Island
xcrun simctl launch --terminate-running-process booted $BUNDLE -demoLiveActivity YES -demoVerdict b   # same, ending on sample key b (Fake deal); also c, d, e
xcrun simctl io booted screenshot shots/history.png
```

Sketches to match are in `sketches/`.

## Rules for every change
- Follow the Worldscape design language: `design/worldscape-language.md` (the spec, with a component
  catalog at the end). Use the tokens and components in `Views/DesignSystem/`, not raw colours or fonts.
- Dark only: near-black canvas `#010101`, white text at fixed opacities, one blue family. Red is for errors.
- Only keys (buttons) have depth. Fields are outlines, cards and bubbles are flat, glass sits over the
  blue `BackdropGradient`, never over plain black. Keep the blue to one place per screen.
- Rounded corners with `style: .continuous`; pills and chips are capsules.
- Touch targets are at least 44pt. Press states replace Worldscape's hover states.
- Motion is springy on arrival and quick or absent on exit; use the `Motion` constants.
- As little text as possible. No explanations where a label or number does the job.
- Only edit `Views/` (and `App/SampleData.swift` for more sample states). Don't change `Models.swift`
  or the function signatures in `ScanAPI.swift`: the backend and the integrator depend on them.
- The widget can't see `Views/`; a palette change goes in `Widget/ScanLiveActivity.swift` too.

## Overridden from the original rules (owner's request, 2026-11-15)
- "Black background, white text, Prussian blue (#003153)" → the Worldscape palette above. The old
  `Theme` names still compile and now map to it (`prussian` → electric blue, `prussianLight` → glow).
- "Square corners. No RoundedRectangle, Capsule or Circle in Views/" → rounded continuous corners and capsules.
- `SharpButtonStyle` now draws the Worldscape key (filled) or quiet outlined key; `Chip` is a capsule.
