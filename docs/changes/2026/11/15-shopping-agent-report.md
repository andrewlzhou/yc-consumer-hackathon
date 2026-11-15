# 2026-11-15 — Shopping agent: report sections, speed, product links

- Author: Claude (Opus 5.5) in crew thread YCCO-4 for Captain Ruhaan, requested by Ruhaan Singh.
- Instructions: close backend gaps for features 1-5 and 7, make card and full report fast with before/after numbers, accept a product URL via the stores thread's resolver without slowing the live path; saved in [agent](../../../backend/agent.md) and [report](../../../backend/agent-report.md).
- Changed: `/report` gains deterministic `insights` (forecast range and confidence, retailer patterns, discount authenticity, competitor spec comparison) and a chart-ready `chart`; it returns the newest analysis.
- Changed: the full run starts on first sight and is one prefetched model pass with no tool turns; provisional products get one frugal SerpApi refresh; prompt no longer treats a scan above stored prices as contradictory data.
- Changed: `/analyze` accepts `url` (alone or with a title), resolved in the background and remembered in `resolvedUrls`.
- Checks: typecheck, `npx vitest run` with keys unset, check_docs; live numbers to follow in this note.
