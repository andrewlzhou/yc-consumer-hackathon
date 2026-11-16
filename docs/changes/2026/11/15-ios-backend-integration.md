# 2026-11-15 — iPhone app wired to the Convex backend

- Author: Claude (Opus 5.5) for Andrew.
- Instructions: Andrew asked to integrate the front end (`checkprice-ios`) with the backend (`main`). No new lasting rules.
- Changed: brought Ruhaan's `ShopperKit` (from `ruhaan_ios`) into `ios/`, with sale events added to the report chart model.
  Check price now checks a clipboard store link or a picked screenshot via `POST /analyze`, plays the real verdict in the pop-up,
  starts a thread, and polls `GET /report` for real price history and forecast. Save syncs the backend watchlist.
  Key via git-ignored `ios/Config/Secrets.xcconfig`; without it the app keeps the demo. See [ios/AGENTS.md](../../../../ios/AGENTS.md).
- Checks: ShopperKit `swift test` 22/22 passed; `ios/scripts/typecheck.sh` app and widget ok; `xcodegen generate` ok, key reaches Info.plist.
- Not verified: no full Xcode or Convex login on this Mac, so no simulator build and no live call with the real key.
- Next: build on a Mac with Xcode, add the key, try a Best Buy XM5 link end to end; Shortcut/App Intents entry is not ported yet.
