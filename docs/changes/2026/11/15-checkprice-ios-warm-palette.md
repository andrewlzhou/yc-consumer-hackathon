# 2026-11-15 Check Price iPhone: Anthropic-style warm palette

- Author: Claude (Opus agent), for Andrew.
- Instructions: owner: match the Anthropic colour feel, lots of white, grey and black with some orange now and then; remove the blue gradient at the top. Saved in `ios/AGENTS.md` (Design rules, Live Activity colours).
- Changed: every blue is gone from the app and widget. Canvas `#141413`, text warm off-white `#FAF9F5` at the old opacity steps, fills and strokes unchanged. One accent, `Palette.accent` orange `#D97757`: the primary key, text carets, field highlight, the streaming caret, the Save swipe. Neutral greys: `Palette.muted` `#B0AEA5` (chart's 12-month low), `Palette.stone` `#5E5D58` (Heart swipe, avatar). The blue names (electric, iris, ultramarine, glow, link, linkPressed, quietBlue) are deleted, as are `AppColor`, `ScreenBackdrop` and `BackdropGradient`; every tab now sits on the flat canvas. The input bar, the verdict hero's light, glass shadows and the secondary key are warm greys; the Live Activity's checking wisps are warm greys with an orange bottom edge, same shape and motion.
- Verdict colours unchanged (none were blue): Buy green `#3DDC97`, Wait amber `#FFB547`, Look around lavender `#C4A7FF`, Check first coral `#FF9466`. Coral sits close to the orange accent.
- Checks: `scripts/typecheck.sh` passed (app and widget), `check_docs.py` passed. No full Xcode on this Mac, so no simulator build and no screenshots; nothing was looked at.
- Next: view it on a device or simulator; the hero panel and input bar greys were picked by number, not by eye.
