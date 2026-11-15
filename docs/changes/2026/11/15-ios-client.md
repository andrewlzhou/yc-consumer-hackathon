# 2026-11-15 iPhone client (YCCO-10)

- Author: Capy (Opus 5.5) for Ruhaan Singh, via Captain Ruhaan.
- Instructions: iOS work lives on branch `ruhaan_ios` and only touches `ios/**`, `docs/ios/**` and doc indexes;
  shared API key only from ignored debug config. Saved in [iOS plan](../../../ios/plan.md) and CREW.md.
- Changed: added `ios/ShopperKit` (contract models, Vision OCR, extraction rules, HTTP client, device id) with
  fixture and client tests, an `ocrdump` dev tool, the SwiftUI app with App Intents, and iOS docs
  ([status](../../../ios/status.md), [app](../../../ios/app.md)).
- Checks: `swift test` in ios/ShopperKit: 10 tests pass; fixture accuracy in [extraction](../../../ios/extraction.md).
  App builds for the iOS simulator on Revyl's runner (Xcode 27). `python3 scripts/check_docs.py` passes.
- Next: SwiftUI app and App Intents; Xcode 26.3 on the Mac; physical iPhone tests are not done yet.
