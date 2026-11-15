# 2026-11-15 — Not Yet iOS: waiting states and Live Activity restyle

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: no new lasting guidance; task scope was the report sheet's loading state, the Live Activity and Dynamic Island, and the Check Price shortcut action.
- Changed: the report sheet's waiting screen now lists four steps (find product, check prices, price history, verdict) driven by the poll's status and step text, and shows the quick verdict as a "First look" card while the full report loads.
- Changed: failures now say what happened: no product, check failed, can't reach the server (45 s with no answer), or over 5 minutes. The last two offer "Try again", which restarts polling.
- Changed: Live Activity and Dynamic Island use the Worldscape palette; the verdict word leads in its colour; words, icons and colours for all five verdicts copy `Verdict` in `App/Models.swift` ("Look around", "Check first" for the new two); unknown verdicts show "Ready". The progress bar now fills over the full 25 s quick-check timeout, and a timeout reads differently from an error.
- Checks: `swiftc -typecheck` on the macOS SDK (Swift 5 and 6 modes) of `ReportLoader.swift` with the design system and stubs, and of the widget's views with a stubbed `ScanAttributes`: no errors. Not compiled for iOS; `ActivityConfiguration`/`DynamicIsland` and `CheckPriceIntent` were not typechecked (iOS-only APIs).
- Checks: `python3 scripts/check_docs.py` passed.
- Next: check the `09-digging` CI screenshot and a real Live Activity on a phone. The widget keeps its own copy of the verdict table; change both together.
