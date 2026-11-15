# 2026-11-15 Backend base merge

- Author: Claude (Opus 5.5) for Andrew.
- Instructions: Andrew decided that Ruhaan's backend is the team base, that paid APIs (SerpApi, Keepa) are allowed with
  SerpApi kept swappable, and that the model picks the final verdict. Saved in [decisions](../../../project/decisions.md)
  and [data providers](../../../backend/data-providers.md). Screenshot handling is recorded as an open question.
- Changed: merged `origin/ruhaan_backend` (382967b) into `main` with no conflicts; adi's `notyet/` untouched.
  `ruhaan_backend-wip-agent` was not merged. Data-providers doc now has the layered data plan.
- Checks: `npm ci`, `npm run typecheck` and `npm test` pass under Node 24 (23 files passed, 1 skipped; 173 tests
  passed, 2 skipped: the live-model test). `python3 scripts/check_docs.py` passes.
  No Convex deploy and no paid API calls were made.
- Next: this Mac's Node 20.17 is too old for vitest 5 (needs 22.12+); upgrade Node to run tests locally.
  Andrew sets `SERPAPI_API_KEY` and `KEEPA_API_KEY` on the shared dev deployment. The deploy rule in
  [orchestration](../../../backend/orchestration.md) still says deploy from the `ruhaan_backend` tip; Ruhaan should
  say whether deploys now come from `main`.
