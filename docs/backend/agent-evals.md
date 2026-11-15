# Shopping agent: evals and latency

- Cases: `eval/cases.json` (data thread): 5 seeded scenarios plus 5 adversarial ones (inflated was-price,
  256GB vs 128GB, OCR-mangled title, unknown product, missing price). All seeded history is sample data.
- CI: `convex/agent/evals.test.ts` runs every case on the deterministic fake provider (live and full tiers).
- Real model: `node eval/run.mjs [--full] [--out file]` on the deployment; it never records prices or uses the cache.
- Scoring in code: product match (family and variant), verdict in the acceptable set, confidence ceiling, grounding.
  Wording and "mustNot" rules are read by a person from the printed reasons.

## Results, 2026-11-15 (real OpenAI models on the dev deployment)

- Live tier (gpt-5.4-mini, card-only output, key facts in the prompt): 10/10 acceptable verdicts, 10/10 correct
  matches, 10/10 grounded, all on the model path (no heuristic fallback).
- Full tier (gpt-6.1-sol, reasoning low, tool loop): see the latest run in the session note; 8-15 s per product.
- What changed the score: the first prompt made every product WAIT for Black Friday (6/10 generic reasons, no numbers,
  confidence 0.93). Adding exact `key_facts` (savings vs past event lows, cheaper comparables, flags such as
  `pastEditionsBeatTodayBy5Percent`) and verdict rules fixed AirPods (BUY_NOW) and Bose (CONSIDER_ALTERNATIVE).
- Thin history: the model said BUY_NOW on Ember's 3 observations once; the code guardrail forced INVESTIGATE.

## Latency (live path over HTTP, 18 scans of seeded products)

- Fresh live pass: p50 1.44 s, p95 1.78 s. Cached analysis: p50 0.14 s, p95 0.17 s. Response 296-367 bytes.
- Model time dominates (1.0-1.6 s). Card-only output cut it from 2.4-3.2 s (full report, ~380 output tokens).
- Unclear titles add one hybrid search (embedding call) plus a model pick: about 1.4 s more (OCR case).
- Unknown product: INVESTIGATE in 0.2-0.9 s; the full run is queued in the background.

## Still wrong or unverified

- The full tier once called the inflated was-price case INVESTIGATE while its text said "buy at Target": the model
  noticed a cheaper retailer but mapped it to the wrong verdict. Data was polluted by a latency probe at the time.
- Seeded history only: no real-history product has been evaluated yet (real ingestion is the data thread's).
- Forecast ranges come from past event lows; their calibration is untested.
