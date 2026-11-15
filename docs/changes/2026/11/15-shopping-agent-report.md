# 2026-11-15 — Shopping agent: report sections, speed, product links

- Author: Claude (Opus 5.5) in crew thread YCCO-4 for Captain Ruhaan, requested by Ruhaan Singh.
- Instructions: close backend gaps for features 1-5 and 7, make card and full report fast with before/after numbers, accept a product URL via the stores thread's resolver without slowing the live path; saved in [agent](../../../backend/agent.md) and [report](../../../backend/agent-report.md).
- Changed: `/report` gains deterministic `insights` (forecast range and confidence, retailer patterns, discount authenticity, competitor spec comparison) and a chart-ready `chart`; it returns the newest analysis.
- Changed: the full run starts on first sight and is one prefetched model pass with no tool turns; provisional products get one frugal SerpApi refresh; prompt no longer treats a scan above stored prices as contradictory data.
- Changed: `/analyze` accepts `url` (alone or with a title), resolved in the background and remembered in `resolvedUrls`.
- Changed: integrated YCCO-8's no-fetch URL hints and typed background resolver; URL-only scan→page resolution→report is covered by integration tests; live URL-only /analyze (Apple, Walmart links) answered in 0.17-0.33 s from the slug hint, with full reports ready.
- Instructions: add copy-paste instructions to try the backend without an iOS app or app API key; [try it now](../../../backend/try-now.md) uses Convex-authorized internal evals.
- Changed: internal evals return results without saving analyses, scan logs, observations, jobs or running SerpApi. Background lookups are capped at one product/day (up to two searches), leaving room for the five-product daily refresh within 250/month.
- Instructions: Captain decision (2026-11-15): Bose at its $339.99 year low is CONSIDER_ALTERNATIVE while the Sony XM5 is $198; the report keeps the year low and names trade-offs. Saved in the eval case's rationale and the prompt; real demo after it: 9/9 live, 7/7 full, all grounded.
- Checks: typecheck, 155 tests passed (2 live push tests skipped), check_docs; fresh checkout `npm ci`; documented no-write live demo kept analysis and scan-log rows unchanged. Full generation p50 12.19→8.78 s; scan→full ready p50 14.22→11.01 s (small samples, changing shared data).
