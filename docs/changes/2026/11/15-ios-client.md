# 2026-11-15 iPhone client (YCCO-10)

- Author: Capy (Opus 5.5) for Ruhaan Singh, via Captain Ruhaan.
- Instructions: iOS work lives on branch `ruhaan_ios` and only touches `ios/**`, `docs/ios/**` and doc indexes;
  shared API key only from ignored debug config. Saved in [iOS plan](../../../ios/plan.md) and CREW.md.
- Changed: added `ios/ShopperKit` (contract models, Vision OCR, extraction rules, HTTP client, device id) with
  fixture and client tests, an `ocrdump` dev tool, the SwiftUI app with App Intents, and iOS docs
  ([status](../../../ios/status.md), [app](../../../ios/app.md)).
- Changed (review): fixed YCCO-11's wrong-price and privacy findings (sale pairs, superscript cents from glyph
  geometry, banner/address text, variant and cart prices, store names in titles, intent file handling, analyze retry).
- Checks: `swift test` in ios/ShopperKit: 22 tests pass; fixture accuracy in [extraction](../../../ios/extraction.md).
  Simulator build on Revyl (Xcode 27); unsigned device build on the Mac (Xcode 26.3). `check_docs.py` passes.
- Device: Back Tap -> Shortcut -> intent proven on Ruhaan's iPhone 14 (8+ runs, intent p50 2.25 s, p95 3.70 s);
  Shortcuts' temp PNG is now deleted (proven). "Best Buy App" title defect fixed. Popup/deep link moved to YCCO-13.
- Next: Ruhaan to confirm Photos is unchanged; backend defects (AE link, Amazon /dp/, reason math) are CON-10/YCCO-12.
