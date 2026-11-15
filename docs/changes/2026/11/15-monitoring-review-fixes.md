# 2026-11-15 Monitoring review fixes

- Author: Capy monitoring thread (YCCO-5), for Ruhaan Singh, from the YCCO-7 review of b546796.
- Instructions: fix the monitoring and watchlist findings with a regression test per High; keep status.md current (rule already in AGENTS-linked crew docs).
- Changed: seed-derived verdicts and lows can no longer notify; watchlist functions are internal; routes fail closed with a per-device rate limit; fresh in-stock current price; simulated drops keep the baseline; device register patches only sent fields; sent-only indexes; cron refreshes real prices via SerpApi with a cap; dead APNs tokens cleared. See [monitoring](../../../backend/monitoring.md).
- Checks: `env -u OPENAI_API_KEY -u SERPAPI_API_KEY npm test` 131 pass; tsc; check_docs. Edited two other-thread test assertions that tested my functions (agent.test null snapshot, retrieval.test real-only priorLow).
- Next: live check on the shared deployment after push.
