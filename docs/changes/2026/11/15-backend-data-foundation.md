# 2026-11-15 — Backend foundation and data

- Author: Claude (Opus 5.5) in crew thread for Captain Ruhaan, requested by Ruhaan Singh.
- Instructions: backend work lands on `ruhaan_backend` with crew rules; saved in [orchestration](../../../backend/orchestration.md) and decisions.
- Instructions: Ruhaan's specs 00-04 condensed into `docs/backend/` (product, contract, data, agent, monitoring, iOS capture).
- Changed: `convex/lib/contract.ts` (phone contract, extended with deviceId, url, ocrLines, matchedTitle, isSampleData).
- Changed: first `convex/schema.ts` (retailers, products, priceObservations, saleEvents, priceDigests).
- Changed: vitest + convex-test setup, `npm test` and `npm run typecheck`, a CI backend job, `!convex/data/` in .gitignore.
- Checks: `npm run typecheck` passed; `npm test` 1 passed; schema deployed to a local anonymous Convex backend; check_docs passed.
- Changed: retrieval functions in `convex/data/` (catalog match, bounded history, exact stats, promo patterns, calendar, digests, recordObservation) and a reproducible seed (`npm run seed`).
- Checks: `npm test` 22 passed, including per-scenario numbers for every seeded product; seed loaded on the local backend (2728 points).
- Changed: `eval/cases.json` (5 seeded + 5 adversarial cases), SerpApi Google Shopping adapter (fixture-tested), `provider` on observations; `npm run seed` is now an action, one mutation per product, keeping product ids stable.
- Changed: Best Buy live price (`getLivePrice`, optional, never stored) and a Keepa adapter (unused after Ruhaan ruled out paid APIs), both fixture-tested from the docs, not live; see [data providers](../../../backend/data-providers.md). Caution: with `CONVEX_DEPLOY_KEY` set, `convex dev --once` deploys to the shared dev deployment even in anonymous mode; unset it for local runs.
- Changed: embeddings live in `productEmbeddings`; deployed product rows still carried `embedding`, so one deploy (24e2962) kept it optional while a tested migration moved 8 vectors and cleared the field on the shared deployment; the field and migration are now removed.
- Changed: real demo set in `convex/data/demo.ts` (SerpApi Google price history + Wayback), daily `refresh demo prices` cron in `convex/crons.ts` (monitoring's file, one line), Google change points expanded to daily steps, Amazon pages no longer read template text as out of stock; seeding skips products that are real.
- Changed: tighter SerpApi offer matching (model-shape conflict, earbuds vs headphones, bundles/kits, 40-200% MSRP band) after YCCO-5 saw a $148 XM6 match; tested on real shopping results.
- Changed: `eval/cases-match.json` + `data/matchEval:run` (text vs hybrid with the agent's decision rules), `data/demo:removeObservationsAt` operator cleanup, demo ingest embeds the product.
- Changed: catalog scoring: `variantConflict` (sibling model like XM4 vs XM5, line words like Air/Digital, earbuds, accessory words) halves text scores and drops hybrid candidates.
- Checks: demo set ingested on scintillating-caterpillar-190 (XM5 720 points, XM6 706, Bose 366, AirPods Pro 3 393, PS5 1); two wrong XM6 rows ($148, $249) from the old matcher removed; match eval text 32/34, hybrid 31/34. See [data-demo](../../../backend/data-demo.md).
- Loose ends: no real WAIT-for-Black-Friday or never-charged was-price case exists today; Ninja has no first-party offers; brand products from YCCO-8 not folded in yet.
