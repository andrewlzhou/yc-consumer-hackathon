# iPhone client status (resume here)

- Branch `ruhaan_ios` (from `ruhaan_backend`). Plan: [plan.md](plan.md). Owner thread: YCCO-10 (Captain Ruhaan).

## Works

- `ios/ShopperKit` Swift package: contract models, Vision OCR wrapper, price and title rules, HTTP client with
  one bounded retry, anonymous device id. `cd ios/ShopperKit && swift test` passes on macOS with only Command
  Line Tools (Swift 6.1). Fixture accuracy and `swift run ocrdump <png>`: see [extraction](extraction.md).

- SwiftUI app "Worth It" (`ios/Shopper`): Check (link or picked screenshot), result card, report with chart,
  watchlist edit/remove, inbox, setup with timings; App Intents for screenshot and link. Builds for the simulator
  on Revyl's runner (Xcode 27). How to build and use: [app](app.md).

- Review fixes (YCCO-11): wrong-price and privacy regressions covered by `AdversarialTests.swift`; intent reads
  the screenshot under security scope and deletes only app-owned files; timed-out `/analyze` is not repeated.
- Mac build: Xcode 26.3 at `/Applications/Xcode-26.3.app`; use `DEVELOPER_DIR=/Applications/Xcode-26.3.app/Contents/Developer`
  (xcode-select still points to Command Line Tools). Unsigned device build passes.

- Real iPhone 14 (A15, iOS 27.0.1): free Personal Team build installs and runs (Xcode 26.3, `DEVELOPER_DIR`).
  Measured 2026-11-15 over USB with the debug hook ([device test](device-test.md)), test device id `ios-test-ycco10-*`:
  - Link: Best Buy XM5 -> BUY_NOW, 0.96 s fresh, 0.20 s cached. AE Baggy Jean link: first try timed out at 5 s,
    second gave INVESTIGATE ("one old record") as a provisional product. Amazon `/dp/B09XS7JWHH`: backend could
    not resolve it ("couldn't read a product name"), so INVESTIGATE.
  - Screenshot pipeline on the phone (saved public store pages): OCR 0.07-0.21 s; Amazon XM5 -> BUY_NOW (3.9 s
    total, 3.7 s network, fresh analysis); AirPods page title only -> BUY_NOW 0.39 s; bot-check, carousel and
    AppleCare screens -> "No product found" with no network call. Test images were deleted after reading.

- Back Tap -> Shortcut -> intent on the real phone (Ruhaan, 16:15-16:28): 8 runs reached the app with real
  full-screen screenshots (1.2-1.6 MB PNG). Intent time (OCR + backend): p50 2.25 s, p95 3.70 s (n=7 with a
  product); OCR p50 0.16 s, p95 0.43 s; backend p50 2.0 s, p95 3.6 s. One non-product screen correctly sent nothing.
- Handoff: Shortcuts passes a PNG it owns in `/var/mobile/tmp/com.apple.WorkflowKit.BackgroundShortcutRunner/`,
  with `removedOnCompletion` off. Since 0d24267 the intent deletes that copy after reading it; proven on the phone
  (later run: deleted = true, 0.94 s total). Files in Documents, Files or Photos are never touched.
- Result shows as a popup over the store app with a blue system affordance under it (Ruhaan); a compact popup and
  a deep link into the real app (ios/CheckPrice on main) belong to YCCO-13 on `ruhaan_ios_bridge`.
- Defect found and fixed: a Best Buy home screen sent "Best Buy App" as a title (store chrome is now rejected).

## In progress

- Nothing in this branch. Photos before/after count still to be confirmed by Ruhaan.

## Not verified yet

- Photos unchanged after Back Tap (Ruhaan to confirm); the intent's time limit (longest observed run 3.7 s).

## Gotchas

- Vision's default minimum text height drops most phone-screenshot text; we set 0.008 of the image height.
- Retailers' bot checks block headless Chrome (Walmart, Target, Best Buy); use real phone screenshots instead.
- Never commit `ios/Config/Secrets.xcconfig`, screenshots, provisioning profiles or device ids.
