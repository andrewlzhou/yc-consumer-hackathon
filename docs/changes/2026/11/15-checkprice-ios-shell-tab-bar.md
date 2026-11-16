# 2026-11-15 Check Price app shell and tab bar

- Author: Claude agent (Opus), for Andrew. One of five agents working in parallel on branch `checkprice-ios`.
- Instructions: owner spec "three tabs — Home, Threads, Account" and, on the bar, "this bar should be the first version's glassy effect UI and there should not be a search button and only that one row of three elements."
- Finding: Not Yet's bar (`notyet/ios/Views/RootTabView.swift`) is the system `TabView` with a fourth tab given the `.search` role; iOS 18 draws that as the separate round search button. Check Price leaves that tab out.
- Changed: `ContentView` is now a system `TabView` with three tabs: Home (`house`), Threads (`bubble.left.and.bubble.right`), Account (`person`). `Components/TabBar.swift` holds `AppTab` and `TabBarStyle`, Not Yet's tab bar appearance copied as is (dark blur at 55% near-black, faint top hairline, white icons at 36% and 94%, Hiragino W5 labels); `CheckPriceApp` applies it at launch and puts `ThreadStore.shared` in the environment.
- Changed: each tab sits on `ScreenBackdrop`, so screens should not draw their own. The root no longer pads screens; each screen sets its own margins. A thread's detail opens as a sheet whenever `ThreadStore.openThreadID` is set and clears it on dismiss. Home's old `report` flag is bridged to open the newest thread until Home sets `openThreadID` itself.
- Changed: launch arguments are `-startTab home|threads|account`, `-autoReveal YES`, and `-openThread YES` (replaces `-openReport YES`; opens the newest thread). `WatchlistView` and `ReportView` are deleted. `ios/AGENTS.md` updated.
- Checks: `xcodegen generate`; all Swift type-checked as Mac Catalyst iOS 18 in Swift 5 and 6 modes with no errors or warnings. Not built for iOS or run; the bar has not been seen on screen.
- Not verified: whether a screen that wraps itself in a `NavigationStack` hides the root backdrop. If it does, that screen can add `.containerBackground(.clear, for: .navigation)`.
