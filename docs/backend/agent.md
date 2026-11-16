# Shopping agent

- Owned by the shopping-agent thread. Code in `convex/agent/`; routes in `convex/agent/http.ts`. Built from spec 02.
- Status: built and verified on the dev deployment with real models; numbers in [agent evals](agent-evals.md).

## How a scan flows

- `POST /analyze` validates the extract by hand, then calls `agent/analyze:analyzeScan` (internal action).
- Identify: `matchProduct` re-ranks full-text hits; clear matches (score >= 0.75, 0.15 lead, no size conflict) are
  taken in code. Otherwise `hybridSearch` (text + vector, text-only without a key) feeds the fast model, which picks one or none.
  Vector-only suggestions need 0.6 similarity and a brand match; model/size conflicts are rejected. Failed model picks return no match.
- Record: every priced scan goes through `data/prices:recordObservation` as `source: "scan"`.
- No match: only a usable phone `title` creates a provisional product ([scan safety](agent-scan-safety.md)); INVESTIGATE at once, full run queued.
- Links: a `url` resolved earlier identifies the product exactly; a new one is resolved off the live path (see [report](agent-report.md)).
- Cached: a full analysis under 12 hours old (or a live one under 30 minutes) made within 2% of today's price is returned as is.
- Otherwise the live pass: stats, promo patterns, competitors and exact `key_facts` are fetched in code, then one small
  structured call (verdict, confidence, reason, evidence ids) to the fast model (default `gpt-5.4-mini`, reasoning none), no tools.
  The whole live path has a 4 s budget (the phone waits 5 s); with under 0.8 s left the deterministic analyst answers.
- The full run is queued on first sight, in parallel with the live pass (one per product at a time, `analysisJobs`).

## The full run

- `agent/analyze:runFullAnalysis`: all evidence is prefetched in code (stats, promo, competitors, `key_facts`,
  `insights`, `price_sources`), then one structured call to the larger model (default `gpt-6.1-sol`, low), no tool turns.
  Tool turns cost ~3s each and measured 8-14s per run before; see [evals](agent-evals.md).
- Provisional products first get one SerpApi refresh (offers and Google price history), at most once a day per
  product and one product a day overall (up to two searches). `tools.ts` remains available for the loop in `loop.ts`.
- `port.ts` presents tool results to the model: timestamps become ISO dates, fractions become percents.

## Grounding

- Output follows one JSON schema (`output.ts`), enforced by OpenAI strict mode and re-checked in code.
- Every tool result gets an evidence id (E1, E2, ...). Each text field cites ids; `evidence.ts` checks that every
  number in it appears in a cited result (display rounding allowed) and that competitors came from a competitor tool.
  Stated price relations must also hold ("within N% of", "N% below", "matches", "new low"); see [scan safety](agent-scan-safety.md).
- Problems go back to the model for a repair turn. Still failing, or a confident verdict on thin history
  (< 5 observations or < 30 days), falls back to the deterministic analyst in `heuristic.ts`, whose text only copies numbers.
- When any evidence is seed data, the reason ends with "(sample data)" and `isSampleData` is true.

## Stored analysis (`analyses` table)

- One row per run: tier (live/full), source (model/heuristic), model, verdict, confidence, reason, report,
  the full evidence trail (tool, args, result as JSON text), grounding issues, latency, token usage.
- Report sections written by the model (each with evidence ids) plus deterministic `insights` and a chart:
  see [report](agent-report.md).

## Config (Convex env)

- `OPENAI_API_KEY` (missing => fake provider), `AGENT_PROVIDER=fake` to force the fake,
  `AGENT_FAST_MODEL`, `AGENT_FAST_REASONING`, `AGENT_FULL_MODEL`, `AGENT_FULL_REASONING`.
- `APP_API_KEY`: every route (agent and watchlist) requires it as `x-api-key`; without it routes answer 401. Set
  `APP_ALLOW_UNAUTHENTICATED=1` only for local dev (tests do).
- `/analyze` requires `deviceId` and is rate limited (`limits.ts`): 20/min per device (burst 10), 600/h overall,
  10 new provisional products/h per device. Over the limit: 429.

## Monitoring hook

- `agent/monitor.ts` gives monitoring's `getSnapshot` the newest analysis (verdict, confidence, reason,
  alternative, `isSampleData`) and queues a full run when the analysis is missing, stale, or made at a different price.
  Monitoring must not push on `isSampleData` snapshots (guardrail owned by the monitoring thread).
