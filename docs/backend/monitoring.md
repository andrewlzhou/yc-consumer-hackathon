# Watchlist and monitoring

- Owned by the monitoring thread. Push delivery research is in [monitoring-push](monitoring-push.md).
- Identity is an anonymous client-made `deviceId` (8-128 chars). This is NOT authentication: anyone who knows an id can edit that list.
- Optional `APP_API_KEY` env var: when set, the HTTP routes require it as an `x-api-key` header.

## Tables (convex/watchlist/tables.ts)

- `devices`: deviceId, apnsToken, environment (sandbox for Xcode debug builds, production for TestFlight/App Store).
- `watchItems`: deviceId, productId, targetPrice, per-trigger prefs, last price/verdict seen, last check time.
- `notificationLog`: one row per decision, sent or suppressed (why), price, verdict, judge, simulated flag. Used for cooldowns, dedupe, debugging and the in-app inbox.

## API (HTTP routes in convex/watchlist/http.ts; same functions are callable from the Convex client)

- `GET /watchlist?deviceId=` list. `POST /watchlist/save` upsert/edit `{deviceId, productId, targetPrice?|null, prefs?}`.
- `POST /watchlist/remove {deviceId, productId}`. `POST /watchlist/device {deviceId, apnsToken?, environment}`.
- `GET /watchlist/notifications?deviceId=` unacknowledged sent notifications (the local-notification fallback). `POST /watchlist/notifications/ack {deviceId, ids}`.
- Prefs are booleans: target_hit, new_low, buy_now_flip, sale_start, better_alternative (all on by default).

## How a check runs

- Cron `monitor watchlist` runs every 4 hours (convex/crons.ts) and schedules one `monitoring/check:checkProduct` per watched product, 1 second apart.
- `checkProduct` asks `monitoring/ports:getSnapshot` (the only file that touches the data and agent threads) for a fresh price and analysis.
- Per device watching it: code lists candidate events (target crossed, new low, flip to BUY_NOW, sale start, better alternative), applies the guardrails, then the judge picks.
- First check for a watch is a baseline: it records price and verdict and never notifies.
- Judge: OpenAI chat call when `OPENAI_API_KEY` is set (`MONITOR_JUDGE_MODEL`, default gpt-4.1-mini), else a deterministic rules judge. It can only pick a listed candidate. Notification body is the agent's reason line.
- Guardrails (convex/monitoring/policy.ts), re-checked inside the commit mutation: no seed or unlabeled simulated price, per-trigger prefs, dedupe on device+product+trigger+price, 24h cooldown per device+product (a further 10% drop overrides), minimum drop max($0.50, 1%).

## Delivery

- APNs if the device has a token and the four `APNS_*` env vars exist; otherwise (or on APNs failure) the row stays in the inbox and the app raises a local notification from the live query.

## Demo helper

- `npx convex run monitoring/simulate:dropPrice '{"deviceId":"...","productId":"...","price":79.99}'` judges a pretend price for that one device. Title starts with [Simulated]; nothing is written to price history.

## Tests

- `npm test` covers policy, judge (mocked OpenAI), APNs client (local HTTP/2 server) and the full flow with convex-test.

## Status

- `ports.getSnapshot` is not wired to the data and agent functions yet; see the latest change note.

