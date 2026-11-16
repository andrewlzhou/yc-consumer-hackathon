# 2026-11-15: iOS quick sweep for things that did not make sense

- Author: Claude (three subagents, one each for Home, Threads and backend, Account and design system), requested by Andrew.
- Instructions: a six-minute sweep to fix things that plainly do not make sense; no new features or UI. One-off, so no lasting rule was added.
- Changed: the "Back to Shopping" tile showed the total checks (38) beside the top store's name; it now shows that store's own count (14), matching the stats screen.
- Changed: when the backend sends no "lowest" entry, the report's low price was dated today; it now takes the date of the cheapest history point.
- Changed: removed the unused `ProfileAvatar` view, and corrected two comments in `ThreadDetailReport` that described older behaviour. `ios/AGENTS.md` updated to match.
- Checks: `ios/scripts/typecheck.sh` passed for the app and the widget; `python3 scripts/check_docs.py` passed. Nothing was run in the simulator.
- Next: left alone because they need a decision, not a fix:
  - Home's "Checks 3" counts real threads; the stats screen's 38 checks is invented sample data, so the two disagree on screen.
  - Home's "Saved" is the predicted saving from waiting, not money saved.
  - The Currency setting does not change the chart, which always shows US dollars.
  - VoiceOver reads the tabs as "Threads" and "Account"; the screens are titled "Library" and "Settings".
  - `Components/Card.swift` and `Components/Metric.swift` are unused.
  - The Widget, LiveActivity and Shared folders, and DesignSystem files other than `PriceChartView`, were not read.
