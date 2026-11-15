# iPhone client status (resume here)

- Branch `ruhaan_ios` (from `ruhaan_backend`). Plan: [plan.md](plan.md). Owner thread: YCCO-10 (Captain Ruhaan).

## Works

- `ios/ShopperKit` Swift package: contract models, Vision OCR wrapper, price and title rules, HTTP client with
  one bounded retry, anonymous device id. `cd ios/ShopperKit && swift test` passes on macOS with only Command
  Line Tools (Swift 6.1). Fixture accuracy and `swift run ocrdump <png>`: see [extraction](extraction.md).

## In progress

- SwiftUI app + App Intents (screenshot and link) built with XcodeGen on Revyl's cloud runner.
- Xcode 26.3 install on Ruhaan's MacBook Air (macOS 15.7.9 can't run Xcode 26.4+ or 27).

## Not verified yet

- Anything on a physical iPhone: Shortcut screenshot handoff, Photos untouched, in-place result, time limit.

## Gotchas

- Vision's default minimum text height drops most phone-screenshot text; we set 0.008 of the image height.
- Retailers' bot checks block headless Chrome (Walmart, Target, Best Buy); use real phone screenshots instead.
- Never commit `ios/Config/Secrets.xcconfig`, screenshots, provisioning profiles or device ids.
