# 2026-11-15 Watchlist and monitoring

- Author: Capy monitoring thread, for Ruhaan Singh.
- Instructions: build watchlist and background monitoring on branch ruhaan_backend; see [monitoring](../../../backend/monitoring.md).
- Changed: watchlist tables, HTTP routes, inbox, notification policy and judge, APNs client, cron sweep, simulated drop, data-layer port.
- Checks: npm test (48 pass), tsc, check_docs; live: OpenAI judge call, APNs probe from Convex cloud (403 InvalidProviderToken), HTTP CRUD and notify flow on a local backend.
- Side effect: one deploy to the shared dev deployment dropped three agent-thread indexes; their redeploy restores them.
- Next: wire the agent's analysis into ports.ts when it lands; live push needs APNs key and a real iPhone.
