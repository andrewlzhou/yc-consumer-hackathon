# 2026-11-15 Watchlist and monitoring

- Author: Capy monitoring thread, for Ruhaan Singh.
- Instructions: build watchlist and background monitoring on branch ruhaan_backend; see [monitoring](../../../backend/monitoring.md).
- Changed: watchlist tables, HTTP routes, inbox, notification policy and judge, APNs client, cron sweep, simulated drop. See monitoring docs.
- Checks: npm test, npx tsc --noEmit -p convex, python3 scripts/check_docs.py.
- Next: HTTP routes, simulated drop, wiring to the data and agent functions, live checks once keys reach the machine.
