# Status by workstream

- Each thread edits only its own section after every push. Written for a stranger on any model or account.
- Local Convex check (never the shared deployment): `env -u CONVEX_DEPLOY_KEY -u CONVEX_DEPLOYMENT CONVEX_AGENT_MODE=anonymous npx convex dev --once`.
- Tests: `env -u OPENAI_API_KEY -u SERPAPI_API_KEY npx vitest run`; typecheck: `npm run typecheck`.

## Data and retrieval (convex/data, convex/seed, eval/cases*.json)

- Works (see git log): catalog match (full text, OCR fixes, size and variant conflicts) and hybrid vector search;
  bounded history, exact stats, promo patterns, was-price checks, sale calendar, digests; recordObservation/recordBatch.
- Real data on the shared deployment: 5 demo products from Google price history (SerpApi) plus Wayback pages,
  refreshed daily by the `refresh demo prices` cron. Numbers and supported verdicts: [data-demo.md](data-demo.md).
- Offer guards: no other model (XM5 vs XM6), no earbuds for headphones, no bundles or used, 40-200% of MSRP.
- Match eval (`npx convex run data/matchEval:run`, 34 titles): text 32/34, hybrid 31/34. Text is the decision;
  hybrid only rescues OCR-mangled titles (8/8 vs 7/8) and over-suggests near-duplicates (5/7 vs 7/7).
- Seed: `npm run seed` for the remaining sample products (iPad, Ninja, Ember), labeled; it skips real products.
- Next steps: fold in YCCO-8's brand products; consider a stricter vector bar for hybrid suggestions (agent side).
- Gotchas: SerpApi free plan is 250 searches/month (cron uses 5/day); never call it in tests. Wayback pages are gzip;
  use exact-URL CDX queries. Fix wrong rows with `data/demo:removeObservationsAt`, never by hand.

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
- Verified live on the shared deployment (tip 022b41c): 401 without or with a wrong key, CRUD + prefs, bad environment 400,
  save schedules refresh+check, simulated drop below target sent (inbox), repeat held by cooldown, baseline unchanged,
  ack empties the inbox, sweep scheduled checks. Local run with real keys: OpenAI judge sent new_low, sample flip blocked.
- Real data live (XM6, api rows from SerpApi): a real check sent buy_now_flip via the OpenAI judge with the agent's reason.
  That flip came from the INVESTIGATE placeholder, so placeholders are no longer stored as baseline verdicts.
- Next steps: real-price pushes now depend only on prices moving; real iPhone push needs APNS_* and a device.
- Gotchas: seed rows anywhere in the window block verdict pushes; lone scans are ignored (trustedPoints);
  previous lows are real-only, so demo drops on seeded products need a target price.
