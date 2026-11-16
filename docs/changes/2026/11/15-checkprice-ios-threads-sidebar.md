# 2026-11-15 Check Price iPhone: Threads list as a sidebar

- Author: Claude (Opus agent), for Andrew.
- Instructions: owner: make the Threads list look like the Claude app's sidebar, very minimal: Watchlist and similar lists on top, then recent threads with all tags removed. Saved in `ios/AGENTS.md` (Files, Threads entry).
- Changed: the All / Hearted / Saved chips are now two nav rows, Watchlist (saved threads) and Hearted, each with a thin outline symbol; each pushes a screen with only those threads and an empty-state symbol. Below them a "Recents" label and every thread newest first, no Today / This week / Earlier groups. Rows show only the product name on one line: no verdict, price, time, marks, card fill or separators. Tap, swipe and long-press to heart or save still work. The day grouping and the "All" filter are gone.
- Conflict: the pushed Watchlist and Hearted screens show their name in the bar, which breaks the no-titles rule; the task spec asked for it. Recorded as an exception in `ios/AGENTS.md`; the owner may want it removed.
- Checks: `scripts/typecheck.sh` passed (app and widget). No full Xcode on this Mac, so no simulator build, no screenshots, and the layout was not seen.
- Next: look at the screen on a simulator: spacing of nav rows, Recents label size, back-button text on the pushed screens.
