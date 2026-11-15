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

## In progress

- Signing: Xcode needs a Personal Team identity (Settings > Accounts > Manage Certificates > Apple Development).
- Phone: iPhone 14 on iOS 27.0.1 is paired; Developer Mode must be turned on before install.

## Not verified yet

- Anything on a physical iPhone: Shortcut screenshot handoff, Photos untouched, in-place result, time limit.

## Gotchas

- Vision's default minimum text height drops most phone-screenshot text; we set 0.008 of the image height.
- Retailers' bot checks block headless Chrome (Walmart, Target, Best Buy); use real phone screenshots instead.
- Never commit `ios/Config/Secrets.xcconfig`, screenshots, provisioning profiles or device ids.
