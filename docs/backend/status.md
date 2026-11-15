# Status by workstream

- Each thread edits only its own section after every push. Written for a stranger on any model or account.
- Local Convex check (never the shared deployment): `env -u CONVEX_DEPLOY_KEY -u CONVEX_DEPLOYMENT CONVEX_AGENT_MODE=anonymous npx convex dev --once`.
- Tests: `env -u OPENAI_API_KEY -u SERPAPI_API_KEY npx vitest run`; typecheck: `npm run typecheck`.

## Shopping agent (convex/agent, convex/http.ts routes)

- Works: POST /analyze (live card), GET /report, full tool-loop analysis, grounding checks, rate limit, fail-closed key.
  Verified on the shared deployment with the real model (gpt-5.4-mini live, gpt-6.1-sol full); see eval numbers in the report.
- Eval: `node eval/run.mjs [--full]` against the deployment (needs the deploy key); CI runs the same cases on the fake provider.
- Config (Convex env): OPENAI_API_KEY, APP_API_KEY, optional AGENT_FAST_MODEL / AGENT_FULL_MODEL / AGENT_*_REASONING.
- In progress: nothing. Open: M3 provisional-product junk (matchProduct still returns provisional rows), real-product
  lookup via SerpApi for unknown products (background run currently only analyzes what is already stored).
- Next steps: wire an unknown-product lookup (data thread's SerpApi adapter, cached per normalized title) into runFullAnalysis.
- Gotchas: deploy only from a clean origin/ruhaan_backend tip. Seed data makes the reason end with "(sample data)".
  The convex-test rate limiter needs `rateLimiterTest.register(t)` in any test that calls /analyze or analyzeScan.
