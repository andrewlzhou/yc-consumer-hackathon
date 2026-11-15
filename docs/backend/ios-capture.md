# iOS capture (phone side, reference)

- Condensed from Ruhaan's spec 01 (2026-11-15). The phone is not built in this repo yet; this page tells backend
  builders what the phone will send and how it behaves.

## How capture works

- iOS lets no app see another app's screen. The sanctioned route is a Shortcut whose Take Screenshot action hands
  the image to our App Intent. Back Tap runs the Shortcut first; Control Center or the Action Button can later.
- Text is read on-device with Apple Vision (fast recognition, language correction off so model numbers survive).
- Rules first: largest text near the top for the title, price patterns, words like "was". If rules can't fill title
  and price, use Apple's on-device model (Foundation Models, iOS 26) or send pruned OCR lines to the backend.
- Prefer null over a guess. Expect price noise: "$25/mo" financing, shipping, unit prices, ranges, search grids.

## Risky assumptions to test on a real iPhone first

- Take Screenshot passes the image without saving it to Photos, and captures the retailer app, not Shortcuts.
- The intent can show output over the retailer app without switching apps; find the time limit.
- If any fail, report alternatives (Share extension, Action Button) before building further.

## Privacy

- The image stays in memory only and is never written to disk; delete any system temp file even on failure.
- Only extracted fields, or in the fallback a few pruned text lines, leave the device.

## Backend call

- Plain URLSession POST to the Convex HTTP endpoint on `.convex.site`, with the [extract](contract.md),
  the anonymous `deviceId`, and a shared API key header.
- About a 3 second timeout; Convex doesn't auto-retry, so the phone retries once.
- Plain-language failures: no product found ("open a product page and try again"), network error, timeout.
- Simple dialog for the verdict now; an interactive card with a Save button is later front-end work.
