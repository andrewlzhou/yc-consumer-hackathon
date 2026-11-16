# 2026-11-15 Check Price iOS: Account tab, laid out like an Instagram profile

- Author: Claude agent (Opus), one of five parallel agents, for Andrew.
- Instructions: owner asked that Account follow normal account-page behaviour, using Instagram as the model, with one or two features of our own. Task-specific; recorded here only.
- Changed: Account shows the handle and a gear in the top bar; a round avatar (initials, or a person symbol) beside three counts: Checks (all threads), Saved (saved threads) and Saved by waiting (for each saved thread, its price minus the low end of its projected low, added up; $70 on the demo data); then name, bio, and Edit profile and Share profile keys.
- Changed: under the profile, Hearted and Saved tabs show threads as a three-column grid of verdict-tinted glass tiles with the product symbol and price; a tap opens the thread through `ThreadStore.openThreadID`. Each tab has a one-line empty state.
- Changed: Edit profile is a sheet with name, handle and bio fields, saved on the device with `@AppStorage` when Done is pressed. Share profile sends a line of text, since there is no profile page to link to.
- Changed: the gear pushes Settings: the three old Setup steps, then Notifications, Privacy and About. Every row except About's version number says "Not connected yet". `SetupView.swift` is deleted; nothing referenced it after the new tab bar.
- Checks: `xcodegen generate`, then the Mac Catalyst iOS 18 type-check of all app Swift files in Swift 5 and 6 modes: no errors or warnings in the Account files. The dollar parsing was run on sample strings. Not built for iOS or run; nothing seen on screen.
- Next: `ios/AGENTS.md` still lists `SetupView` under Files; whoever owns it should drop that. Judge the tile tint, avatar and stat sizes by eye in the simulator. The pushed Settings screen draws its own plain canvas, not the blue backdrop.
