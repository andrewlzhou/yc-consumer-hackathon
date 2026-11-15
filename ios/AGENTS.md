# Check Price iPhone app (`ios/`)

- This is the main iPhone app (owner decision, 2026-11-15). It started as a teammate's SwiftUI prototype: capture → analyzing → verdict reveal → report → watchlist, with demo data only. No Convex, screenshot capture, Shortcut or notifications yet; don't describe them as working. The Live Activity (below) runs on demo data only.
- It supersedes `notyet/ios/`. Not Yet stays in the repo for reference until the owner decides what to do with it. Don't edit it for Check Price work.
- Direction: keep this app's screens, flow and content; give them Not Yet's look and interaction design (the Worldscape design language). No new features or screens unless the owner asks. More specific instructions are coming, so keep changes reversible.

## Design rules

- Read `notyet/ios/design/worldscape-language.md`, including the component catalog (section 5). Short version: dark only, near-black canvas, one blue family, white at fixed opacities; only keys have depth; glass only over the blue backdrop; Hiragino Sans by role; springy arrival, quiet exit; one blue place per screen.
- Use the pieces in `CheckPrice/DesignSystem/` (copied from `notyet/ios/Views/DesignSystem/`): `Palette`, `TextStyle`/`.textStyle()`, `Spacing`, `Radius`, `ControlHeight`, `Shadows`, `Motion`, `.transition(.rise)`, `KeyButtonStyle`, `QuietButtonStyle`, `GlassSurface`/`.glassSurface()`, `GlassCardButtonStyle`, `BackdropGradient`, `ScreenBackdrop`, `FlatCard`, `Hairline`, `Chip`, `Bubble`, `OutlinedField`, `ScreenTitle`, `SectionLabel`, `ListRowButtonStyle`, `RoundIcon`, `IconPressStyle`, `HoppingDots`, `ThinkingLine`, `.shimmering()`, `StreamingText`, `WorkingIndicator`, `FailureNote`, `InputBarSurface`, `SampleDataTag`, `ConfidenceMeter`, `PriceChartView`.
- No screen titles (owner, 2026-11-15): no in-content heading that names the screen and no navigation-bar title. Back buttons and bar buttons stay. Section labels that name content (Summary, Price, Chat) are fine. The Account top bar keeps the user's handle, as profile info.
- The tab bar is icons only, no names under them (owner, 2026-11-15): outline when not selected, filled when selected (`house`, `bubble.left.and.text.bubble.right`, `person.crop.circle`). Titles stay on the items, drawn clear, so VoiceOver reads them.
- Verdicts: `Verdict.word`, `.symbol`, `.color` (`DesignSystem/VerdictStyle.swift`): Buy green, Wait amber, Look around lavender, Check first coral.
- `AppColor` (`DesignSystem/AppColor.swift`) is the prototype's colour names pointed at `Palette`, so unrestyled screens still compile. Use `Palette` in new code; delete `AppColor` when nothing uses it.
- How Not Yet drew similar screens: `notyet/ios/Views/` (for example `ProductReportView.swift`, `HomeView.swift`, `HistoryView.swift`).

## Live Activity (Dynamic Island)

- Two stages: `checking` (Worldscape's deep blue wisps, word "Checking") and `decided` (the same wisps re-hued to the verdict, the verdict word, a reason of about 8 words at most). Words: Buy Now, Buy Later (yellow), Look Around, Check First. Never a "don't buy" (owner, 2026-11-15).
- Show nothing else: no store, product name, clock or other icon, no logo yet. The compact leading slot holds only a small wisp glow, kept free for a future logo. Everything is centred; the reason uses New York, Apple's built-in serif (`.system(design: .serif)`), standing in for Granola's serif.
- Colours: checking copies Worldscape's input bar (`InputBarSurface`: `#0E0FA2 → #1121BE → #0833C4`, top `#010428`, bottom light `#2A4FE6`/`#3F64F2`, fog `#DDE6FF`); each verdict has a hand-picked set in `Widget/WispField.swift`. The owner will tune these.
- Platform limits: the island's outer pill is always black, so the art sits inside it; no Metal, TimelineView or looping animation. Motion comes from bumping `phase` in each update (iOS animates up to about 2 s between states).

## Files

- `CheckPrice/ContentView.swift`: root tabs (Home, Threads, Account), the thread detail sheet (shown whenever `ThreadStore.openThreadID` is set, cleared on dismiss), launch arguments. Each tab sits on `ScreenBackdrop`, so screens don't draw their own. `ThreadStore.shared` is also in the environment (`@Environment(ThreadStore.self)`).
- `CheckPrice/Components/TabBar.swift`: `AppTab` and `TabBarStyle`, the system tab bar dressed as Not Yet's dark glass (one row of three, no search tab, icons only), and `TabBarIconInsets`, which moves each icon down into the space the hidden title leaves.
- `CheckPrice/Screens/`: `Home/HomeView` (first screen `Home/PrimaryCheckArea`: capture, analyzing, reveal, swappable as one view; below it `Home/HomeSummary`: totals, verdicts, recent threads), `Threads/ThreadsView`, `Threads/ThreadDetailView` (pushed or sheet: report from `ThreadDetailReport`, demo chart history from `ThreadDetailHistory`, chat from `ChatColumn` and `ChatInputBar`), `Account/AccountView`, and `SetupView` until the Account work replaces it.
- `CheckPrice/Components/`: `Card` (a padded `FlatCard`), `Metric` (label over value), `SignalRow` (product row on a flat card, optional trailing note), restyled in Worldscape. `Badge` is retired.
- `CheckPrice/Models/Demo.swift`: `Verdict`, `Product`, `Demo` data.
- `CheckPrice/LiveActivity/CheckActivity.swift` starts and updates the pop-up (also from Home's reveal); `Shared/CheckAttributes.swift` (app and widget) holds its state; `Widget/` is the widget extension `CheckPriceWidgets` with the views and wisp art.
- When agents work in parallel, each owns its screen files. `Components/`, `DesignSystem/` and `Models/` are shared: add new pieces freely, but change or remove an existing one only by agreement, since other screens use it.

## Build and run

- `cd ios && xcodegen generate` (XcodeGen from Homebrew). The generated `CheckPrice.xcodeproj` is not committed.
- Simulator build: `xcodebuild -project CheckPrice.xcodeproj -scheme CheckPrice -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build build`. The app lands in `build/Build/Products/Debug-iphonesimulator/Check Price.app`. iOS 18+, unsigned.
- Launch arguments (`xcrun simctl launch booted com.ycconsumerhackathon.checkprice <args>`): `-startTab home|threads|account`, `-autoReveal YES` (runs the capture → reveal demo on launch; screenshot within 3.5s for analyzing, after for the reveal), `-openThread YES` (opens the newest thread's detail sheet), `-demoLiveActivity YES` with optional `-demoVerdict wait|buy|alternative|investigate` (default wait: "Checking" for 6 s with the wisps moving every 1.5 s, then the verdict with an alert). iOS hides an app's own Dynamic Island while the app is open, so swipe home right after launch. `-autoReveal YES` also plays the pop-up over 3.5 s.
- Without full Xcode, run `scripts/typecheck.sh`: it type-checks the app and the widget extension as Mac Catalyst iOS 18. ActivityKit and WidgetKit are marked unavailable on Catalyst, so it builds stand-ins from the macOS SDK's interface files with those bans removed. This is not an iOS build.
