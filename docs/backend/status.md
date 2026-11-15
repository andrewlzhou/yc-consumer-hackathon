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

- Works (b1d9b44): POST /analyze, GET /report with chart, forecast, retailer discount patterns, spec comparison;
  grounded one-pass full report starts in parallel with the card. Auth/rate limits and monitoring hook work.
- Latest real-model eval: original cases 10/10 live, 9/9 full; real demo 8/9 live, 6/7 full (Bose recommends a
  cheaper Sony instead of expected BUY_NOW). Full p50 8.8 s; initial report sections ~1.8 s. See agent-evals.md.
- Eval: `node eval/run.mjs [--cases eval/run-cases-demo.json] [--full]`; see [try it now](try-now.md).
- Config (Convex env): OPENAI_API_KEY, APP_API_KEY (set on the dev deployment), optional AGENT_FAST_MODEL,
  AGENT_FULL_MODEL, AGENT_*_REASONING.
- Verified: the documented no-write real demo leaves the latest analysis and scan-log rows unchanged. Next: wire
  YCCO-8's no-fetch parseUrl when it lands and prove URL-only resolution; missing resolver falls back to extract.
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

## More stores

- Reader/resolver: c6ad7ea. Three demo additions are connected: AE Baggy Jean, lululemon Align 25-inch, Nike Zenvy.
- Local: full suite 166 passed, two live tests skipped; targeted tests also cover AE ingestion and variant-preserving URLs.
- Next: deploy a clean origin/ruhaan_backend tip, ingest the three products, then verify rows, URL resolution and competitors.
