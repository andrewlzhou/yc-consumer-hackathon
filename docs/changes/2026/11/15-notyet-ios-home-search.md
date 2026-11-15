# 2026-11-15 Not Yet iOS: Home and Search in Worldscape

- Author: Claude agent (Opus), one of the restyle agents, for Andrew.
- Instructions: no new lasting guidance; task rules (own files only, keep `-startTab`, `.settingsButton()`, Router and mock mode, in-content `ScreenTitle` like History) were followed.
- Changed: Search's ask bar is Worldscape's blue input bar (grows to four lines, white arrow, mic). Asking shows the question as a bubble with hopping dots and the step it is on, in the report sheet's step words; the steps advance on a clock because `ScanAPI.ask` reports no progress. The arrow becomes a stop square that cancels and puts the question back.
- Changed: ask failures stay by the bar and say what to do (no connection, too slow, or try the exact model name) with a "Try again" chip. A denied mic says to allow it in Settings, with a chip that opens Settings.
- Changed: Home's empty state sits on the blue light: the Back Tap line, a glass card that opens the setup sheet, a "Check a screenshot" key, and a pointer to Search. The top-left picker now reads "Check". A screenshot that can't be opened now says so; one that can't be sent for lack of connection closes the sheet and says so instead of digging forever.
- Changed: Discover rows and lists use list cards, round icons and in-content titles. New shared pieces in `notyet/ios/Views/DesignSystem/AskParts.swift`.
- Checks: typechecked all app sources as Mac Catalyst (iOS 18 interfaces) in Swift 5 and 6 modes, previews stripped and the ActivityKit files left out (Router stubbed): no errors or warnings. A planted error was caught, so the check is real. Not built or run on iOS; no screenshots.
- Next: judge the ask bar's blue and the Home backdrop by eye in the simulator; confirm a vertical `TextField` submits on Return on device (a typed newline is also treated as submit).
