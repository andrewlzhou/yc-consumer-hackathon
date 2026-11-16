# 2026-11-15 — Check Price iOS: Watchlist sparkline spike

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: no new lasting guidance; task scope was the vertical line at the left of every Watchlist sparkline on Home.
- Cause: not a bad point. Every demo history has a Labor Day sale (Aug 29 to Sep 3, 9 to 17% under the regular price) a few days after the first point of the 90-day window. On a 64 by 28 pt sparkline that sale is about 3 pt wide and, as the lowest price, spans the full height, so it drew as a line straight down and back up at the left edge.
- Changed: `HomeTrend` (`ios/CheckPrice/Screens/Home/HomeCards.swift`) leaves out prices inside a past sale window and zero prices; the sparkline's y range is now the prices' min to max with 15% room either side instead of Charts' automatic range.
- Not changed: the report's `PriceChartView`. Its left edge starts from the price in force at the window start, and its sale dips are intended and shaded, so it has no such artifact.
- Checks: the demo histories run through the new filter on the Mac give smooth series (QuietComfort 353 to 349, AirPods 208 to 189, Vertuo 130 to 129, no dip). `ios/scripts/typecheck.sh`: app and widget ok. `python3 scripts/check_docs.py` passed. Not seen on a device.
