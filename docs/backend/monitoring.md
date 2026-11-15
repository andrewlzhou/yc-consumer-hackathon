# Watchlist and monitoring

- Owned by the monitoring thread. Push delivery research is in [monitoring-push](monitoring-push.md).

## Access

- Identity is an anonymous client-made `deviceId` (8-128 chars). It is NOT authentication: anyone holding the app key and a deviceId can edit that list.
- All watchlist functions are `internal`; the only way in is the HTTP routes, so the app key cannot be bypassed via the Convex client.
- Routes fail closed: with `APP_API_KEY` unset on the deployment every route answers 401 naming the missing setting; a missing or wrong `x-api-key` answers 401.
- Rate limit: 60 requests per minute per deviceId (fixed window, `rateLimits` table), then 429.

## Tables (convex/watchlist/tables.ts)

- `devices`: deviceId, apnsToken, environment (sandbox for Xcode builds, production for TestFlight/App Store).
- `watchItems`: deviceId, productId, targetPrice, per-trigger prefs, last real price/verdict seen, last check time.
- `notificationLog`: one row per decision, sent or suppressed (why), price, verdict, judge, simulated flag. Indexed by status so cooldown, dedupe and the inbox only read sent rows.

## HTTP API (convex/watchlist/http.ts; every call needs `x-api-key`)

- `GET /watchlist?deviceId=` list. `POST /watchlist/save` upsert/edit `{deviceId, productId, targetPrice?|null, prefs?}`.
- `POST /watchlist/remove {deviceId, productId}`.
- `POST /watchlist/device {deviceId, apnsToken?, environment?}`: only sent fields change; `apnsToken: null` clears it; environment is required the first time and must be sandbox or production.
- `GET /watchlist/notifications?deviceId=` unacknowledged sent notifications (the local-notification fallback). `POST /watchlist/notifications/ack {deviceId, ids}`.
- Prefs are booleans: target_hit, new_low, buy_now_flip, sale_start, better_alternative (all on by default). Unknown keys are a 400.

## How a check runs

- Cron `monitor watchlist` every 4 hours schedules one `monitoring/check:checkProduct` per watched product, 1 second apart. The first `MONITOR_REFRESH_CAP` (default 10) also refresh prices; saving a product does too.
- Refresh calls the data thread's SerpApi `refreshCurrentPrices` (source `api`, 1-2 searches) unless a real price is under 6 hours old.
- `monitoring/ports.ts` is the only file touching the data and agent threads. Current price = cheapest latest row per retailer that is in stock and fresh (api 72h, scan 24h), real rows before seed rows. No fresh price means no check.
- Previous low and typical price use real (non-seed) rows only. If any seed row is in the window, or the agent's analysis says isSampleData, the verdict counts as sample-derived and BUY_NOW-flip and better-alternative notifications are blocked.
- Per device: code lists candidate events, applies guardrails, then the judge picks. The first real check is a baseline and never notifies.
- A crossed target price notifies without the judge (the user asked for it). Judge for the rest: OpenAI when `OPENAI_API_KEY` is set (`MONITOR_JUDGE_MODEL`, default gpt-4.1-mini), else a deterministic rules judge. It only picks a listed candidate. Body is the agent's reason line.
- Guardrails (policy.ts), re-checked inside the commit mutation: seed or unlabeled simulated price, sample-derived verdict, prefs, dedupe on device+product+trigger+price, 24h cooldown per device+product (a further 10% drop overrides), minimum drop max($0.50, 1%).

## Delivery

- APNs if the device has a token and the four `APNS_*` env vars exist, else the inbox. BadDeviceToken, Unregistered or DeviceTokenNotForTopic clear the stored token.

## Demo helper

- `npx convex run monitoring/simulate:dropPrice '{"deviceId":"...","productId":"...","price":79.99}'` judges a pretend price for that one device. Title starts [Simulated]; nothing is written to price history and the watcher's baseline is not moved.
- Previous-low facts are real-only, so on a product with only seeded history give the watch a target price above the simulated price.

## Tests

- `npm test`: policy, judge (mocked OpenAI), APNs client (local HTTP/2 server), HTTP auth and rate limit, full flow with convex-test. Tests force the rules judge and no SerpApi key.
- `npm run test:live` calls the real OpenAI judge.
