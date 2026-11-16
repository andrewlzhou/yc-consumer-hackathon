# 2026-11-15: merge checkprice-ios into main

- Author: Claude (subagent), requested by Andrew: "put checkprice onto main".
- Instructions: on conflicts, the owner's UI decisions win (no in-app check on Home, `AppBackdrop` behind every screen, the branch's screen layouts); keep all of main's backend work (Ruhaan's bridge, `CheckSnapshot`, `ReportFigures`, Back Tap, `CheckPriceTests`). One-off, so no lasting rule was added.
- Changed: `ReportFigures` keeps main's rule that a check keeps its own price, store, verdict and reason, and adds the branch's report sources, the cheapest-point date for the low, and the longer reasoning (only from an analysis made for the same price).
- Changed: the detail page uses the branch's Why / Prediction / Sources layout with main's report loading (`loadReportIfNeeded`) and main's "waiting for report" line; the Prediction block is hidden when there is nothing to show.
- Changed: `PrimaryCheckArea` stays deleted. Its no-key message and island reason served only that screen; the Shortcut actions already show the no-key failure.
- Changed: fixed two places where the sides no longer fit: the saved-checks archive still passed the removed heart flag, and Home's sparkline used the old report-figures call.
- Changed: `project.yml` keeps the branch's asset-catalog settings and main's test target and scheme. `ios/AGENTS.md` and `docs/ios/bridge-status.md` now describe the merged app (no `-autoReveal`, no hearts, checks only from Shortcut actions).
- Checks: `ios/scripts/typecheck.sh` passed (app and widget). The unit tests were type-checked against the merged app with a stand-in for XCTest: passed. `python3 scripts/check_docs.py` passed. No conflict markers; `git diff --check` clean.
- Next: not run: `xcodegen generate`, the simulator build, or the unit tests (no full Xcode on this Mac). Not tried on a real iPhone; the Revyl build was not re-uploaded.
