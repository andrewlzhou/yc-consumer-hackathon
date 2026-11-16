# 2026-11-15 — Not Yet iOS: Worldscape design system foundation

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: the Worldscape design language replaces adi's original UI rules (palette, square corners). Saved in `notyet/ios/UI_WORKFLOW.md` with a short list of what was overridden. Foundation only; two other agents restyle the screens.
- Changed: added `notyet/ios/Views/DesignSystem/` (palette, Hiragino type roles with fallback, spacing, radii, shadows, motion, keys, glass, backdrop gradient, outlined field, bubble, flat card, chip, loading pieces).
- Changed: `Views/Theme.swift` keeps every old name, now mapped to the new tokens; the widget's colour copy matches. Component catalog added to `notyet/ios/design/worldscape-language.md`.
- Checks: typechecked the design system and `Theme.swift` with `swiftc -typecheck` on the macOS SDK in Swift 5 and Swift 6 modes, UIKit parts stubbed, plus a usage file calling every component: no errors. Not compiled for iOS (no Xcode here); the other screens and the widget were not typechecked.
- Checks: `python3 scripts/check_docs.py` passed.
- Next: build in Xcode or CI and check the screenshots; confirm which Hiragino Sans weights the iPhone has; judge `BackdropGradient` by eye; record the design decision in `docs/project/decisions.md` (outside this session's allowed paths).
