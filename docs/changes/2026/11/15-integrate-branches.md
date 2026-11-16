# 2026-11-15 — Branches merged into main

- Author: Claude (Opus 5.5) for Andrew.
- Instructions: Andrew asked that all branches be integrated. No new lasting rules.
- Changed: merged `ruhaan_backend` (same commit as `ruhaan_backend_phonefix`) and `checkprice-ios` (which already
  holds `ui-worldscape-design`) into `main`. README and decisions conflicts kept both sides.
- Not merged: `screenshots` (CI output only). `ruhaan_ios` clashes with Check Price in `ios/` and committed build
  output; its ShopperKit package is already in `ios/ShopperKit`, and its App Intents are not ported yet.
- Checks: docs check passed; `npm run typecheck` ok; vitest 175 passed, 2 skipped; `ios/scripts/typecheck.sh` app and
  widget ok; ShopperKit `swift test` 22/22.
- Next: decide how `ruhaan_ios`'s Shortcut intents join Check Price.
