# 2026-11-15 Check Price iOS: Dynamic Island in Hiragino Sans, extras removed

- Author: Claude agent (Opus), for Andrew.
- Instructions: owner, on the island mockup: use the Worldscape font, not a serif; remove anything not needed; add nothing. Recorded in `ios/AGENTS.md` (Live Activity).
- Changed: the reason line uses `HiraginoSans-W3` instead of New York; the verdict word stays `HiraginoSans-W6`. The compact leading and minimal slots are now `EmptyView()` (the wisp glow `WispOrb` is deleted); the thin border on the expanded card is gone. Demo reasons sent by `CheckActivity` are a few words (for example "~$40 less by Cyber Monday").
- Checks: `xcodegen generate` and `ios/scripts/typecheck.sh` (app and widget, Mac Catalyst iOS 18 stand-in): ok. Not run on an iPhone or simulator.
- Next: confirm on a device that iOS accepts an empty compact leading slot without odd spacing. Home's reveal still sends the product's longer summary (`PrimaryCheckArea.swift`, not changed here).
