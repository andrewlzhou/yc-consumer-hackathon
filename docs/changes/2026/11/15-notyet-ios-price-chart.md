# 2026-11-15 — Not Yet iOS: Worldscape price chart

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: no new lasting guidance. Task scope: restyle only `notyet/ios/Views/PriceChartView.swift` so the chart makes the buy-or-wait case at a glance.
- Changed: the chart now shows a white step line (the backend sends a point only when the price changed), a dashed typical-price line, the 12-month low as a blue dot, today as a dot in the verdict colour, the dashed projection, and shaded past sale windows.
- Changed: a row above the chart reads "Today / Typical / 12-mo low" with prices. Dragging across the chart swaps that row for the day's date, store, sale name and price, with a selection haptic. On arrival the marks spring from a flat line into shape; Reduce Motion skips it. "Sample data" shows when the report is flagged.
- Changed: typical price and low use the backend's `typicalPrice` and `lowest` when present, else they are computed from `history` (time-weighted median; lowest price). The old initializer still works; new `init(result:projected:projectedDate:accent:)` passes all the new fields.
- Checks: `swiftc -typecheck` (Swift 6, macOS 15 SDK, UIKit font lookup stubbed) passed with the real `Models.swift`. Ran the number logic on the sample history: typical $249, low $199 on Dec 1, a mid-July drag reads $219 at Amazon during a Prime Day window.
- Checks: not compiled for iOS and not seen on a screen (no Xcode here). Untested: how dragging on the chart interacts with scrolling the report, and how the arrival animation looks.
- Next: `ProductReportView` should switch its call to `PriceChartView(result: result, projected: projected, projectedDate: waitDate, accent: style.color)` to get the backend's typical price, low, sale windows and sample label.
