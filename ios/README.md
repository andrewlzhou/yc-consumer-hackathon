# Check Price iPhone prototype

This SwiftUI prototype demonstrates the consumer-facing flow with demo data only. It does not yet connect to Convex, capture a screenshot, create a Shortcut, run a Live Activity, or send notifications.

## Run

On a Mac with [XcodeGen](https://github.com/yonaskolb/XcodeGen), run `xcodegen generate` in this folder. Open `CheckPrice.xcodeproj` in Xcode and run it on an iOS 18+ simulator or device.

Copy this whole folder to the project as `ios/`. The main product flow is: capture → agent status → verdict reveal → full report → watchlist.
