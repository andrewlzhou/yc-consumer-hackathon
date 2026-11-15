# Shopping agent: evals and latency

## Run it

- [Try it now](try-now.md): fresh checkout, no-write real-model demo, optional authenticated HTTP smoke test.
- `node eval/run.mjs --full`: original 10 scenarios (sample/adversarial); `--cases eval/run-cases-demo.json`:
  real-history products (electronics plus AE, Nike, lululemon from YCCO-8), a buy-elsewhere scan, two look-alikes,
  an OCR-mangled title, and an Align scan whose only prices are three-month-old archives.
- `--full-model gpt-6.1-terra:none` or `gpt-5.4-mini:none` compares models without changing deployment settings.
- Evals skip cache and all app writes, including analysis rows and scan logs; no SerpApi lookup or jobs.
  OpenAI calls still cost tokens. CI uses the fake provider; scores cover match, verdict, confidence and citations.

## Real-model results (shared dev, 2026-11-15)

- Original cases after the changes: 10/10 matches, 10/10 acceptable live verdicts, 9/9 full verdicts and grounded
  reports (`full-4`). The unknown product correctly gets no full run in this no-write eval.
- Real demo (`demo-2`): 9/9 matches, 8/9 live and 6/7 full; the miss was Bose, expected BUY_NOW at its $339.99
  year low while the agent chose the Sony XM5 at $198 (41.8% less). Captain decision (2026-11-15): better value
  wins, so the case now expects CONSIDER_ALTERNATIVE; rationale and history are kept in the case file.
- After that decision and a prompt fix (`demo-3`): 9/9 matches, 9/9 live, 7/7 full, all grounded. A live Bose report
  names its year low and the trade-offs (Sony: LDAC, older; Bose: spatial and lossless USB-C audio).
- With store products (`demo-4`, e732bda): 12/12 matches, 12/12 live, 10/10 full, all grounded. AE is the first real
  WAIT ($35.97 vs $29.97 at past Black Friday). Nike Zenvy at $105 is BUY_NOW, with no saving claimed from Align's
  stale $98. Align with no scan price first got BUY_NOW at $98: fixed with a guardrail (stored price over 14 days
  old and no scan price means INVESTIGATE); priced scans also no longer reuse a price-less cached analysis.
- The real demo caught a bug: competitor price used the last retailer observed (XM5 at Target, $399.99) instead
  of the cheapest current retailer (Best Buy, $198). Fixed in b1d9b44; XM6 now recommends the XM5 as intended.
- Inflated-was full-tier miss (INVESTIGATE on a scan above stored prices) is fixed: the prompt treats a higher
  scan as today's store price, not contradictory data. Thin history still forces INVESTIGATE.
- Hybrid candidate proxy improved 31/34 to 32/34 after requiring vector score 0.6 and a brand match for vector-only
  rescues. Text remains the first decision; actual real-model picks reject XM4 and AirPods Pro 2, with OCR XM5 rescued.

## Before / after

| Measurement | Before | After |
|---|---|---|
| Full generation, original cases (9 products), p50 / max | 12.19 / 13.85 s | 8.78 / 10.45 s |
| Scan → full ready, HTTP (3 cold products), p50 / max | 14.22 / 16.96 s | 11.01 / 12.09 s |
| First current report sections + chart, HTTP | 12–17 s (older full masked live) | 1.70–1.85 s |
| Fresh card, HTTP (18 scans), p50 / p95 | 1.44 / 1.78 s | 1.46 / 2.13 s |
| Cached card, HTTP, p50 / p95 | 0.14 / 0.17 s | 0.18 / 0.26 s |

- Prefetching removes model tool turns; full generation remains on gpt-6.1-sol/low for quality. It starts alongside
  the card. `/report` returns a newer live analysis instead of hiding it behind an older full report.
- Original card-only change cut the fresh path from 2.4–3.2 s to about 1.4 s; these report changes do not make
  cards faster. OCR adds roughly 1 s for embedding + model identification. Unknown titles return in 0.2–0.5 s.
- Timings are small-sample wall-clock measurements, not an SLA or a controlled A/B: the shared catalog gained real
  history between runs. One after-probe request hit 429; its error payload is excluded from card-size claims.
- Full-model comparisons on the same original cases: sol p50 9.05 s, terra 6.72 s, mini 2.93 s, all 9/9 acceptable.
  Mini needed a thin-history fallback and made weaker prose claims; the production full default stays sol.
- Cards are roughly 300–400 bytes; the detailed report with evidence and chart is roughly 23–31 KB.

## Limits

- Numeric citation checks do not prove semantic entailment; spec/value reasoning and source identity still need review.
- Forecast confidence is heuristic, not statistically calibrated. Seed-only WAIT/pre-sale-hike stories stay labeled.
- No model streaming: chart and deterministic sections arrive first, then the full narrative replaces them.
