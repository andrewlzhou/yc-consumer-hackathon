# Watchlist and monitoring (plan)

- Condensed from Ruhaan's spec 04 (2026-11-15). Owned by the monitoring thread, which replaces this with what it builds.
- Status: not built yet.

## Goal

- Devices save products with an optional target price and preferences, and get a notification only when something
  worth acting on happens, always with a real, explainable reason.

## Suggested design

- Watchlist data: device, product, target price, preferences, and a log of sent notifications for cooldowns and debugging.
- Identity is an anonymous `deviceId` (no accounts). Not production-grade auth; describe it that way.
- A recurring job finds watched products and fans out one short background task per product, so one failure
  doesn't stop the rest.
- Per product: refresh prices, re-run the agent's analysis, decide whether to notify.
- The LLM judges whether a change is a meaningful opportunity. Code keeps hard guardrails: cooldown per product per
  device, minimum meaningful change, dedupe, and never a real notification from seeded data.
- Candidate triggers: target price hit, new historical low, verdict flips to BUY_NOW, a genuine sale starts,
  a better alternative appears.

## Push delivery (decide early)

- Convex's push component targets Expo tokens, which don't fit a native Swift app.
- Real iOS push goes through APNs: Apple Developer account, Push capability, an APNs auth key, a signed token, HTTP/2.
  Check whether Convex's Node runtime can do HTTP/2; otherwise use a relay callable over plain HTTP.
- Fallback: no remote push for the demo; the app watches live Convex queries and raises a local notification.

## Demo helper

- A command to simulate a price drop on a watched product and run the check at once, clearly labeled as simulated.
