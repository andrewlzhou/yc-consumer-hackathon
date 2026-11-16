# Check Price iPhone prototype

This SwiftUI app checks a store link (from the clipboard) or a picked screenshot against the Convex backend and shows the verdict and report. It needs the dev key in `Config/Secrets.xcconfig` (see `Config/Secrets.example.xcconfig`); without it, it runs a demo. Shortcut actions (Back Tap screenshot, link) show a compact verdict with a Details button into the product's thread; not yet proven on a real iPhone. No notifications yet. A Live Activity (Dynamic Island) plays the demo check: launch with `-demoLiveActivity YES` and swipe home.

## Run

On a Mac with [XcodeGen](https://github.com/yonaskolb/XcodeGen), run `xcodegen generate` in this folder. Open `CheckPrice.xcodeproj` in Xcode and run it on an iOS 18+ simulator or device.

Copy this whole folder to the project as `ios/`. The main product flow is: capture → agent status → verdict reveal → full report → watchlist.
