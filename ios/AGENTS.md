# Check Price iPhone app (`ios/`)

- This is the main iPhone app (owner decision, 2026-11-15). It started as a teammate's SwiftUI prototype: capture → analyzing → verdict reveal → report → watchlist, with demo data only. No Convex, screenshot capture, Shortcut, Live Activity or notifications yet; don't describe them as working.
- It supersedes `notyet/ios/`. Not Yet stays in the repo for reference until the owner decides what to do with it. Don't edit it for Check Price work.
- Direction: keep this app's screens, flow and content; give them Not Yet's look and interaction design (the Worldscape design language). No new features or screens unless the owner asks. More specific instructions are coming, so keep changes reversible.

## Design rules

- Read `notyet/ios/design/worldscape-language.md`, including the component catalog (section 5). Short version: dark only, near-black canvas, one blue family, white at fixed opacities; only keys have depth; glass only over the blue backdrop; Hiragino Sans by role; springy arrival, quiet exit; one blue place per screen.
- Use the pieces in `CheckPrice/DesignSystem/` (copied from `notyet/ios/Views/DesignSystem/`): `Palette`, `TextStyle`/`.textStyle()`, `Spacing`, `Radius`, `ControlHeight`, `Shadows`, `Motion`, `.transition(.rise)`, `KeyButtonStyle`, `QuietButtonStyle`, `GlassSurface`/`.glassSurface()`, `GlassCardButtonStyle`, `BackdropGradient`, `ScreenBackdrop`, `FlatCard`, `Hairline`, `Chip`, `Bubble`, `OutlinedField`, `ScreenTitle`, `SectionLabel`, `ListRowButtonStyle`, `RoundIcon`, `IconPressStyle`, `HoppingDots`, `ThinkingLine`, `.shimmering()`, `StreamingText`, `WorkingIndicator`, `FailureNote`, `InputBarSurface`, `SampleDataTag`, `ConfidenceMeter`, `PriceChartView`.
- Verdicts: `Verdict.word`, `.symbol`, `.color` (`DesignSystem/VerdictStyle.swift`): Buy green, Wait amber, Look around lavender, Check first coral.
- `AppColor` (`DesignSystem/AppColor.swift`) is the prototype's colour names pointed at `Palette`, so unrestyled screens still compile. Use `Palette` in new code; delete `AppColor` when nothing uses it.
- How Not Yet drew similar screens: `notyet/ios/Views/` (for example `ProductReportView.swift`, `HomeView.swift`, `HistoryView.swift`).

## Files

- `CheckPrice/ContentView.swift`: root tabs (Home, Threads, Account), the thread detail sheet (shown whenever `ThreadStore.openThreadID` is set, cleared on dismiss), launch arguments. Each tab sits on `ScreenBackdrop`, so screens don't draw their own. `ThreadStore.shared` is also in the environment (`@Environment(ThreadStore.self)`).
- `CheckPrice/Components/TabBar.swift`: `AppTab` and `TabBarStyle`, the system tab bar dressed as Not Yet's dark glass (one row of three, no search tab).
- `CheckPrice/Screens/`: `Home/HomeView` (first screen `Home/PrimaryCheckArea`: capture, analyzing, reveal, swappable as one view; below it `Home/HomeSummary`: totals, verdicts, recent threads), `Threads/ThreadsView`, `Threads/ThreadDetailView` (sheet), `Account/AccountView`, and `SetupView` until the Account work replaces it.
- `CheckPrice/Components/`: `Card` (a padded `FlatCard`), `Metric` (label over value), `SignalRow` (product row on a flat card, optional trailing note), restyled in Worldscape. `Badge` is retired.
- `CheckPrice/Models/Demo.swift`: `Verdict`, `Product`, `Demo` data.
- When agents work in parallel, each owns its screen files. `Components/`, `DesignSystem/` and `Models/` are shared: add new pieces freely, but change or remove an existing one only by agreement, since other screens use it.

## Build and run

- `cd ios && xcodegen generate` (XcodeGen from Homebrew). The generated `CheckPrice.xcodeproj` is not committed.
- Simulator build: `xcodebuild -project CheckPrice.xcodeproj -scheme CheckPrice -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build build`. The app lands in `build/Build/Products/Debug-iphonesimulator/Check Price.app`. iOS 18+, unsigned.
- Launch arguments (`xcrun simctl launch booted com.ycconsumerhackathon.checkprice <args>`): `-startTab home|threads|account`, `-autoReveal YES` (runs the capture → reveal demo on launch; screenshot within 3.5s for analyzing, after for the reveal), `-openThread YES` (opens the newest thread's detail sheet).
- Without full Xcode, type-check as Mac Catalyst: with `S=$(xcrun --show-sdk-path --sdk macosx)`, run `swiftc -typecheck -target arm64-apple-ios18.0-macabi -sdk "$S" -Fsystem "$S/System/iOSSupport/System/Library/Frameworks" -I "$S/System/iOSSupport/usr/lib/swift" $(find CheckPrice -name '*.swift')`. Run it inside `ios/`. This is not an iOS build.
