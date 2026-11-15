# 2026-11-15 — Backend foundation and data

- Author: Claude (Opus 5.5) in crew thread for Captain Ruhaan, requested by Ruhaan Singh.
- Instructions: backend work lands on `ruhaan_backend` with crew rules; saved in [orchestration](../../../backend/orchestration.md) and decisions.
- Instructions: Ruhaan's specs 00-04 condensed into `docs/backend/` (product, contract, data, agent, monitoring, iOS capture).
- Changed: `convex/lib/contract.ts` (phone contract, extended with deviceId, url, ocrLines, matchedTitle, isSampleData).
- Changed: first `convex/schema.ts` (retailers, products, priceObservations, saleEvents, priceDigests).
- Changed: vitest + convex-test setup, `npm test` and `npm run typecheck`, a CI backend job, `!convex/data/` in .gitignore.
- Checks: `npm run typecheck` passed; `npm test` 1 passed; schema deployed to a local anonymous Convex backend; check_docs passed.
- Next: retrieval functions, seed data, source research, eval set.
