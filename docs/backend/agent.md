# Shopping agent

- Owned by the shopping-agent thread. Code in `convex/agent/`; routes in `convex/agent/http.ts`. Built from spec 02.
- Status: built; tests run on the deterministic fake provider. Real-model evals and latency are recorded separately.

## How a scan flows

- `POST /analyze` validates the extract by hand, then calls `agent/analyze:analyzeScan` (internal action).
- Identify: the data thread's `matchProduct` re-ranks full-text hits. Code takes clear matches (score >= 0.75, a
  0.15 lead, no size conflict); close calls go to the fast model, which picks one candidate or none.
- Record: every priced scan goes through `data/prices:recordObservation` as `source: "scan"`.
- No match: a provisional product is created, the phone gets INVESTIGATE at once, and a full run is queued.
- Cached: a full analysis under 12 hours old (or a live one under 30 minutes) made within 2% of today's price is returned as is.
- Otherwise the live pass: stats, promo patterns and competitors are fetched in code, then one structured call to
  the fast model (default `gpt-5.4-mini`, reasoning none) with that evidence in the prompt and no tools.
- After a live pass, a background full run is queued (one per product at a time, `analysisJobs`).

## The full run

- `agent/analyze:runFullAnalysis`: a tool-use loop (`loop.ts`) on the larger model (default `gpt-6.1-sol`, low).
- Tools (`tools.ts`) wrap the data thread's functions: search_catalog, get_price_stats, get_price_history,
  get_promo_patterns, get_sale_calendar, get_price_digest, find_competitors, compare_products, calculate.
- `port.ts` presents tool results to the model: timestamps become ISO dates, fractions become percents.

## Grounding

- Output follows one JSON schema (`output.ts`), enforced by OpenAI strict mode and re-checked in code.
- Every tool result gets an evidence id (E1, E2, ...). Each text field cites ids; `evidence.ts` checks that every
  number in it appears in a cited result (display rounding allowed) and that competitors came from a competitor tool.
- Problems go back to the model for a repair turn. Still failing, or a confident verdict on thin history
  (< 5 observations or < 30 days), falls back to the deterministic analyst in `heuristic.ts`, whose text only copies numbers.
- When any evidence is seed data, the reason ends with "(sample data)" and `isSampleData` is true.

## Stored analysis (`analyses` table)

- One row per run: tier (live/full), source (model/heuristic), model, verdict, confidence, reason, report,
  the full evidence trail (tool, args, result as JSON text), grounding issues, latency, token usage.
- Report sections: match, priceAssessment, discount (status + signals), forecast (low, high, byDate, confidence),
  retailers, competitors (with value reasoning), recommendation. Each section lists its evidence ids.
- `GET /report?productId=` returns the newest full (else live) analysis with evidence, and whether a run is pending.

## Config (Convex env)

- `OPENAI_API_KEY` (missing => fake provider), `AGENT_PROVIDER=fake` to force the fake,
  `AGENT_FAST_MODEL`, `AGENT_FAST_REASONING`, `AGENT_FULL_MODEL`, `AGENT_FULL_REASONING`.
- `APP_API_KEY`: when set, every route requires it in the `x-api-key` header (shared with the watchlist routes).

## Monitoring hook

- `agent/monitor.ts` gives monitoring's `getSnapshot` the newest analysis (verdict, confidence, reason,
  alternative) and queues a full run when the analysis is missing, stale, or made at a different price.
