# 2026-11-15 Not Yet iOS: History, Account, Settings and tab bar in Worldscape

- Author: Claude agent (Opus), one of six restyle agents, for Andrew.
- Instructions: no new lasting guidance; task rules (own files only, tolerate new verdicts, keep `-startTab`, `.settingsButton()`, Router and mock mode) were followed.
- Changed: History rows now show verdict word and colour, retailer, price and time at a glance, in list cards under a blue light at the top; filter chips cover every verdict, including Look around and Check first.
- Changed: Account puts the name and the two counts on a glass card; Settings is two list cards; the tab bar is dark glass with white icons and Hiragino labels.
- Changed: new shared pieces in `notyet/ios/Views/DesignSystem/ListScreens.swift` (`ScreenTitle`, `SectionLabel`, `ListRowButtonStyle`, `RoundIcon`, `ScreenBackdrop`).
- Checks: typechecked all app sources as Mac Catalyst (iOS 18 APIs, Swift 6) with no errors in these files; Live Activity code was left out because Catalyst lacks it. Not built or run on iOS; no screenshots.
- Next: judge the top light, glass card and tab bar colours by eye in the simulator; History titles are drawn in the content, so other tabs may want `ScreenTitle` to match.
