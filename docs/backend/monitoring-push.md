# Push delivery decision

- Decision: send APNs directly from a Convex Node action (`convex/monitoring/apns.ts`, no dependencies). Fallback is the inbox query described in [monitoring](monitoring.md).

## Evidence (2026-11-15)

- Convex actions marked `use node` run real Node 24 (docs.convex.dev/functions/runtimes), so `node:http2` and `node:crypto` exist.
- From a cloud machine, `node:http2` reached api.sandbox.push.apple.com, negotiated h2 via ALPN, and with a throwaway ES256 key got `403 InvalidProviderToken`. That proves the protocol and token format get as far as Apple's validation.
- Not proven: that Convex's hosted Node runtime allows the same outbound call. Run `npx convex run monitoring/apns:probe` on the deployment once; status 403 with InvalidProviderToken means yes.
- Convex's default (non-node) runtime only offers `fetch`; whether it speaks HTTP/2 to APNs is undocumented, so we do not rely on it.
- A real push to a device is untested: it needs Ruhaan's Apple account and a physical iPhone.

## What Ruhaan must set up

- Apple Developer Program membership (paid) and an App ID with the Push Notifications capability; add the same capability in Xcode.
- Create an APNs auth key (.p8) in Certificates, Identifiers & Profiles > Keys. Note the Key ID and Team ID. Download the .p8 once.
- Set on the Convex deployment: `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID` (the app's bundle id) and `APNS_PRIVATE_KEY` (the .p8 text; `npx convex env set APNS_PRIVATE_KEY -- "$(cat AuthKey.p8)"`).
- The app registers its device token with `POST /watchlist/device` and `environment` sandbox for Xcode builds, production for TestFlight and App Store.
- Test on a real iPhone; the simulator cannot get a real token on most setups.

## If Node cannot reach APNs

- Relay the same JSON through any small service that can do HTTP/2 (a Cloudflare Worker or a tiny Node host) and call it with `fetch`. Only `sendApns` in apnsClient.ts would change.

