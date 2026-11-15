# Phone <-> backend contract

- Source of truth: `convex/lib/contract.ts` (TypeScript types plus Convex validators). This page explains it.
- Changing it means changing both sides: update this page and tell the iOS and backend owners.

## Phone -> backend: `ProductExtract`

- Every field is optional. A missing field is handled downstream; a wrong one gives a wrong answer, so send null over a guess.
- `retailer`: what the screen showed, for example "Target" or "walmart.com". The backend normalizes it.
- `title`: product title as read by OCR.
- `currentPrice`: the price the shopper would pay now, in US dollars.
- `originalPrice`: the crossed-out "was" price, if one is shown.
- `deviceId`: anonymous random UUID made on first launch. Not real auth; used for watchlists and rate limits.
- `url`: product URL, when the trigger has one (share sheet, Safari).
- `ocrLines`: fallback only. A few pruned text lines when on-device parsing could not fill title and price.
- `capturedAt`: phone time of the scan, epoch milliseconds.
- The screenshot itself is never sent.

## Backend -> phone: `AnalyzeResponse`

- `verdict`: exactly one of `BUY_NOW`, `WAIT`, `CONSIDER_ALTERNATIVE`, `INVESTIGATE`.
- `reason`: one line for a small card. Every number in it comes from stored data.
- `confidence`: 0 to 1.
- `productId`: our catalog id when the product was identified; use it to save to the watchlist.
- `matchedTitle`: the catalog title we matched, so the phone can show "we think this is ...".
- `isSampleData`: true when any evidence behind the verdict is seeded. The phone must label it as sample data.
- `reportStatus`: `pending` while a fuller background analysis runs (fetch `GET /report?productId=` later), else `ready` or `none`.

## Extensions over the original spec

- Added `deviceId`, `url`, `ocrLines`, `capturedAt` to the extract and `matchedTitle`, `isSampleData` to the
  response (2026-11-15), because spec 01 already sends a device id and spec 00 requires sample data to be labeled.
- The HTTP endpoint, API key header, and error shape are owned by the shopping-agent thread; see [agent](agent.md).
- `deviceId` is now required on `POST /analyze` (rate limiting). Errors: 400 invalid input, 401 bad key, 429 rate limited.
- `GET /report?productId=` and the inbox notification shape are in `contract.ts` (`reportResponseValidator`, `notificationValidator`).
