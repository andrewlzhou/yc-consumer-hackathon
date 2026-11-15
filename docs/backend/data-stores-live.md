# Store deployment verification (2026-11-15)

- Shared dev: `scintillating-caterpillar-190`; code deployed from clean `ruhaan_backend` tips, no index deletions.
- Ingest: `npx convex run data/demo:ingest '{"key":"ae-baggy-jean"}'`; substitute the other keys below.
- All observations below are real `api` or `scrape` data, with no seed points. No paid provider was used.

| Demo key | Product id | Real evidence | Price evidence |
|---|---|---|---|
| ae-baggy-jean | k17929342bfchdczme4z9p7dmh8j82a2 | 91 Google changes expanded to 361 daily points, plus one current offer | $35.97 now; $29.97 low; $37.46 median |
| lululemon-align-25 | k179v8mwbkptn75kjbkn4vqd8d8j9rb3 | 10 unambiguous archived points, May–Aug 2026 | $98 on those dates, NOT verified as today's price |
| nike-zenvy-leggings | k175z3h7phgq9svja298vp637n8j9643 | 9 archived points plus one directly fetched current page | $105 throughout, including today's fetch |

- Apple added 10 priced archive points from 12 samples to the existing AirPods Pro 3 product (336 archive days).
- AE's 365-day window contains 360 points; start-of-window filtering excludes two older expanded days.
- AE's claimed $59.95 price was present on 16 of those 360 represented days (4.4%). It was rarely charged, not never.
- Its advertised 40% saving is only 4% below the actual $37.46 typical; the $29.97 low also appeared at Black Friday 2025.
- The Google product is Black 33×32. The old color-914 archive page is tested but not merged into that history.
- Strict parsing discards conflicting color prices; the first Align backfill's one same-price color-query row was removed.

## Analysis and URL proof

- Real OpenAI eval, AE $35.97 / was $59.95: catalog and variant matched; both tiers returned WAIT with no grounding issues.
- Live: 1,084 ms, confidence 0.86. Full: 8,511 ms, confidence 0.70. These are single measurements, not percentiles.
- Full reason: “Wait: today's $35.97 matches the recent normal price; past Black Friday pricing reached $29.97.”
- No scan prices were written by the eval (`evaluation:true`); the real provider observations support the result.
- Deployed URL resolver: Nike Zenvy → catalog product, current $105; Apple AirPods Pro 3 → existing product, current $249.
- Walmart XM5 → existing catalog product through Wayback. No current price was returned for its old snapshot.
- lululemon Align → catalog product through Wayback, timestamp 2026-08-11. No current price was returned.
- `findComparables` returns Nike Zenvy for lululemon Align (same category, different brand/family).

## Boundaries

- Only AE joins daily Google refresh. The leggings' exact matching Google products were not verified, so they skip it.
- The direct lululemon page is blocked. Its $98 archive price is stale; do not sell the comparison as a current $7 saving.
- Nike/AE/lululemon/Apple are verified on the listed products, not every product in each store.
- Unsupported stores and unresolved variants return no guessed price. Adidas is survey-only.
- 16 cached SerpApi research requests, plus one shared-deployment AE refresh request; cached requests may not consume credits.
- The daily demo refresh now has six Google-enabled products (up to 180 calls/month before other crew usage).
