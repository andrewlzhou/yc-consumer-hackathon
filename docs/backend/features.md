# Feature coverage (backend view, 2026-11-15)

- Status: **live** = verified on the shared deployment with real models; **tests** = convex-test only; **partial**;
  **missing**; **iOS** = phone side. Features from spec 00; owners in brackets when not the agent (YCCO-4).

| # | Bullet | Status | Where | Verified by |
|---|---|---|---|---|
| 1 | Activate (Shortcut, Control Center, Safari, share) | iOS | phone app | - |
| 1 | Identify the product | live | agent/identify.ts, data/catalog, data/embeddings | eval 10/10 matches; match eval |
| 1 | From a product link | live | agent/urls.ts, data/sources/stores [YCCO-8] | URL-only HTTP 0.17-0.33 s; tests |
| 1 | Brief analysis fast | live | POST /analyze | fresh p50 1.46 s, cached 0.18 s |
| 2 | Track history | live (5 real, 3 sample) | data/prices, data/demo [YCCO-3] | data-demo.md |
| 2 | Average price, historical low, high or low today | live | data/stats, key_facts | evals, report |
| 2 | Retailer discount patterns | live | insights.retailerPatterns | report test, /report |
| 2 | Better discount coming: range + confidence | live | insights.forecast, report.forecast | report test, evals |
| 3 | Similar products from other brands | live | data/embeddings:findSimilarProducts | /report, evals |
| 3 | Compare specs, features, prices | live | insights.competitorComparison | report test |
| 3 | Cheaper comparable, better value | partial | prompt rule (20% cheaper), valueReasoning | evals; no value score |
| 4 | Was-price vs history, misleading flag, why | live | stats.wasPrice, discount section | inflated-was eval |
| 4 | Price raised before a sale | live (sample only) | insights.discountAuthenticity.preSaleHikes | report test (Ninja seed) |
| 4 | Repeated discounts | live | discountAuthenticity, sale_price_is_normal_price | report |
| 5 | One of four verdicts with confidence | live | agent/analyze.ts, prompt.ts | evals 10/10, 9/9; real demo 12/12, 10/10 |
| 6 | Watchlist, target prices, preferences | live | watchlist [YCCO-5] | monitoring.md |
| 6 | Keep monitoring prices, judge changes | live | monitoring cron, judge [YCCO-5] | monitoring.md |
| 6 | Push notifications | partial | APNs sender, inbox fallback [YCCO-5] | APNs reachable; no device yet |
| 7 | Price history chart | live | /report chart (agent/chart.ts) | e2e probe, report test |
| 7 | Retailer and competitor comparisons | live | insights, chart series | /report |
| 7 | Discount authenticity, predicted range, explanations | live | insights + model report | full evals |

## The experience, step by step

1. Trigger on the phone (Back Tap first): iOS.
2. Read the screen on-device, discard the screenshot: iOS. The backend accepts extract fields or a link only.
3. Send the extract (or a link): live; a link alone is identified from its slug with no page fetch.
4. Identify, record the price, return the card: live, p50 1.46 s, p95 2.13 s, about 330 bytes.
5. Open the detailed report: live. Deterministic sections and chart about 1.8 s after the scan; the model's
   full report about 11 s after the scan (was 14 s); see [evals](agent-evals.md).
6. Watch the product and get a push: YCCO-5 (inbox works; APNs needs an Apple key and a device).

## Gaps for other owners

- YCCO-5 (feature 6): real push to an iPhone; per-watcher fan-out; status still says deployed products are
  seed-only, which the real demo set has changed, so re-verify a real-price notification.
- YCCO-3 (data): only 5 products have real history; iPad, Ninja and Ember are sample data, so the WAIT-for-Black-Friday
  and pre-sale-hike stories are sample-only. Ninja AF101 has no first-party Google offers. Text match picks a PS5
  for "Xbox Series X" (score 0.63); the agent's model pick is the only guard there.
- YCCO-8: resolver supports Nike, AE, lululemon, Apple and the four retailers; store demo backfills in progress.
- Agent (open): no streaming; a value-for-money score beyond price gap and spec match.
