# Handoff: UI to integration

## Copy into the real project
- `Views/` (all files) into the app target
- `App/` into the app target (replaces the starter versions; ScanAPI now has a mock mode)
- `Shared/` into BOTH the app and widget targets
- `Widget/` into the widget target

## Project settings
- Deployment target iOS 18 or later
- Info.plist (app): NSSupportsLiveActivities = YES, NSMicrophoneUsageDescription,
  NSSpeechRecognitionUsageDescription, URL Types scheme `notyet`
- Paste the real Convex URL into `ScanAPI.baseURL`. That turns mock mode off.
- Fill `Config.shortcutURL` and `Config.proCheckoutURL` in `Views/Theme.swift`

## What changed in the UI (fill this in)
- 
