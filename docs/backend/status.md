# Status by workstream

- Each thread edits only its own section after every push. Written for a stranger on any model or account.
- Local Convex check (never the shared deployment): `env -u CONVEX_DEPLOY_KEY -u CONVEX_DEPLOYMENT CONVEX_AGENT_MODE=anonymous npx convex dev --once`.
- Tests: `env -u OPENAI_API_KEY -u SERPAPI_API_KEY npx vitest run`; typecheck: `npm run typecheck`.

## Data and retrieval (convex/data, convex/seed, eval/cases.json)

- Works (tip of ruhaan_backend, see git log): catalog match (full-text + OCR fixes, size-variant guard) and hybrid
  vector search (`productEmbeddings` table, OpenAI text-embedding-3-small, text-only without a key); bounded history,
  exact stats, promo patterns, claimed-discount checks, sale calendar, digests; `recordObservation` / `recordBatch`.
- Trust rule: scan prices count toward lows, typicals and alerts only when an api/scrape price at the same retailer
  (3 days, 10%) or two distinct devices agree (`trustedPoints` in stats.ts). Only known retailers are stored.
- Real-data adapters: SerpApi google_shopping + google_product (offers and `price_insights` history),
  Wayback snapshots (`data/sources/wayback:ingest`, parsers in `pages.ts`), Best Buy live (optional). Keepa unused (paid).
- Seed: `npm run seed` (action, one mutation per product, stable ids). Seed is a labeled fallback, never the main story.
- In progress: picking the real-data demo set from Wayback density, better Amazon/Target parsers, daily SerpApi refresh.
- Next steps: ingest the demo set into the shared deployment from a clean tip; measure hybrid vs text on eval titles.
- Gotchas: Wayback `id_` pages are gzip; use exact-URL CDX queries; skip captcha stubs. SerpApi free tier is
  250 searches/month: never call it in tests or loops.

## Shopping agent (convex/agent, convex/http.ts routes)

- Works (2b7e6c9): POST /analyze (live card), GET /report, background full tool-loop analysis, grounding checks,
  per-device rate limits, fail-closed API key. Verified live on the dev deployment at 230c0bf (gpt-5.4-mini live,
  gpt-6.1-sol full): live p50 1.44 s / p95 1.78 s, cached 0.14 s; see docs/backend/agent-evals.md.
- Eval: `node eval/run.mjs [--full]` against the deployment (deploy key); CI runs the same cases on the fake provider.
- Config (Convex env): OPENAI_API_KEY, APP_API_KEY (set on the dev deployment), optional AGENT_FAST_MODEL,
  AGENT_FULL_MODEL, AGENT_*_REASONING.
- Blocked: tip deploys fail because deployed products still carry `embedding` (data thread's migration, asked 2026-11-15).
- Next: after a tip deploy, run `npx convex run agent/store:deleteTestArtifacts '{"since": <ms>}'` to drop probe scans,
  then `node eval/run.mjs --full`; then wire an unknown-product lookup (data thread's SerpApi, cached per title) into runFullAnalysis.
- Gotchas: deploy only from a clean origin/ruhaan_backend tip. HTTP probes on the shared deployment record real scan
  rows; clean them up. Tests that hit /analyze need `rateLimiterTest.register(t)`.

## Watchlist and monitoring (convex/watchlist, convex/monitoring, convex/crons.ts)

- Works: HTTP watchlist CRUD, device token, inbox (internal functions only, fail-closed key, 60/min per device);
  4h cron with capped SerpApi refresh; guardrailed notify with OpenAI or rules judge; APNs sender; simulated drop.
  Proven: APNs reachable from Convex cloud (`monitoring/apns:probe` 403 InvalidProviderToken), live OpenAI judge.
- Config (Convex env): APP_API_KEY, OPENAI_API_KEY, SERPAPI_API_KEY; optional MONITOR_REFRESH_CAP (10),
  MONITOR_JUDGE_MODEL; for real push APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY (see monitoring-push.md).
- Open: real push to an iPhone (needs Apple key + device); per-watcher fan-out (one action runs all watchers).
- Next steps: after a clean-tip deploy, save a watch over HTTP, run `monitoring/check:sweep`, read notificationLog.
- Gotchas: seed rows anywhere in the window block verdict pushes; lone scans are ignored (trustedPoints);
  previous lows are real-only, so demo drops on seeded products need a target price.
