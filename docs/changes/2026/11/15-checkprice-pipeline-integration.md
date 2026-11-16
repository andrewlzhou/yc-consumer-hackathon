# 2026-11-15 — Check Price: decision-only popup and honest real-check reports

- Author: Capy (Fable 5.2), thread YCCO-13 for Captain Ruhaan (CON-14, CON-12), branch `ruhaan_ios_bridge`, draft PR #2.
- Instructions: Ruhaan: the popup shows only BUY, WAIT, LOOK ELSEWHERE or INDETERMINATE plus a button titled
  More Details; a real check never shows demo data; real keys never go into cloud builds. Saved in
  [ios/AGENTS.md](../../../../ios/AGENTS.md), [decisions](../../../project/decisions.md) and [status](../../../ios/bridge-status.md).
- Changed: popup is decision only and the whole result opens the check's thread. Fixes from YCCO-15's review: real
  checks never get demo history, and a missing key is a failure, not a demo (H2); a link's price comes only from its
  own store's fresh chart line (H3); a check keeps its own verdict unless the report's analysis was made for the same
  price, and checks are saved on the phone for restarts (H4); temp-file deletion uses fixed folders, symlinks
  resolved (H5); store-chrome text is rejected as title and fallback (M1); a newer report load replaces an older one
  and opening a product no longer waits on the network (M2). H1 is moot: no reason on the popup. Debug-only scan facts.
- Checks: on Revyl (Xcode 27, iOS 26.5 simulator, no key): 20 app tests and 23 ShopperKit tests pass; app builds.
  Docs check passed. Simulator with a mock backend and fake key: a link and a screenshot of a mock store page both
  gave BUY, and More Details opened that product's thread; a blank screenshot gave the failure popup, no request.
- Not verified: this candidate on a real iPhone (Back Tap, file deletion, timing). iOS's own Done button stays.
- Next: YCCO-10 device run; maybe try a confirmation popup, which lets the app name the system button.
