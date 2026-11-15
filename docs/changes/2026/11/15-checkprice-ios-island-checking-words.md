# 2026-11-15 — Check Price iOS: playful checking words in the Dynamic Island

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: owner asked for words like Claude's ("cogitating, rizzazomating") instead of "Checking" while the check runs.
- Changed: while checking, the island, expanded card and Lock Screen show one word from `CheckingWords.all` in `ios/Shared/CheckAttributes.swift` (Cogitating, Haggling, Bargainating, Pricesplaining, Dealsleuthing, Couponjuring, Markdownmusing, Rizzazomating, Thriftulating, Splurgevading). The list is the only place to edit.
- Changed: `ContentState.wordStart` is picked at random when the check starts; the word shown is `wordStart + phase`, so each update shows the next word. Same font (HiraginoSans-W6), opacity transition, no "…" (the old word had none).
- Changed: compact trailing is capped at 100 pt and may shrink to 75%; only "Markdownmusing" (about 125 pt at 13 pt) needs it.
- Checks: `xcodegen generate` and `ios/scripts/typecheck.sh` (app and widget) passed; the HTML island mock re-rendered with "Bargainating". Not run on a device or simulator.
- Next: see the words rotate on Revyl or a phone (`-demoLiveActivity YES`).
