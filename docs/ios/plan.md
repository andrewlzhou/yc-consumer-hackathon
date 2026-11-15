# iPhone client plan (YCCO-10, branch ruhaan_ios)

- Goal: a small, working iPhone prototype that reads a product off the screen on-device and shows the
  backend's verdict, with report, watchlist and inbox. Not UI polish, not production auth.
- Branch `ruhaan_ios` forks `ruhaan_backend`; only `ios/**`, `docs/ios/**` and doc indexes change here.

## Stages

1. Feasibility on a real iPhone (needs Xcode on the Mac and the phone in Developer Mode):
   Shortcut "Take Screenshot" -> our App Intent. Check: the image is the store app, not Shortcuts; nothing lands
   in Photos; the result shows without leaving the store app; how long the intent may run.
   If any fails: stop and propose the share-sheet link path and Action Button alternatives.
2. Extraction (done in `ios/ShopperKit`): Vision OCR on-device (fast level, no language correction, small text
   allowed), line boxes kept; rules pick title, store, current and crossed-out price; blank beats wrong.
   Foundation Models only if the phone has Apple Intelligence; never required.
3. Thin client (done in ShopperKit, app screens next): `POST /analyze` with extract fields or a link only,
   `GET /report`, watchlist save/edit/remove/list, inbox and ack. 5 s analyze timeout, 8 s reads, one retry.
4. Verify: Swift tests on the Mac; app build on Revyl's cloud runner and simulator; then on the phone: XM5,
   XM6, AE Baggy Jean and an unknown product, with a separate test deviceId and no fake prices.
   Measure trigger-to-card, OCR and network time (p50/p95 when there are enough runs).

## Privacy and keys

- The screenshot stays in memory; any temp file Shortcuts hands over is deleted on success and failure.
- Only extract fields, a link, or (when the title can't be read) up to 12 pruned text lines are sent.
- The shared `x-api-key` is loaded from an ignored `ios/Config/Secrets.xcconfig` for private debug builds
  only. Anyone can pull it out of a shipped app, so a real release needs device-bound auth on the backend.

## Done when

- A real iPhone in a shopping app triggers, reads and returns a correct verdict without uploading or storing
  the screenshot, or a precise blocker plus a tested share-link fallback.
- Report, watchlist and inbox screens work; tests and a clean build pass; timings measured; docs current.

## Out of scope

- Backend changes, broad store coverage, production auth, APNs credentials and push, App Store release.
