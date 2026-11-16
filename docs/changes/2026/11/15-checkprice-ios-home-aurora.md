# 2026-11-15 Check Price iPhone: Home is just the check, over an aurora

- Author: Claude (Opus agent), for Andrew.
- Instructions: owner: Home should just be a tap to check what to buy, with better words, and an aurora animation like Worldscape's. Saved in `ios/AGENTS.md` (Files, Home entry).
- Changed: the summary below Home is gone (`HomeSummary`, and `SignalRow`, which only it used). Ready now reads "Worth buying now?" over "Tap anywhere to check."; the whole screen is one button, "Check a price" for VoiceOver; the failure note stays. Analyzing and the reveal are unchanged.
- Aurora (`Home/HomeAurora.swift`): SwiftUI only, TimelineView at 30 fps drawing a Canvas. Five radial-gradient blobs (accent orange, cream, stone) drift on slow loops, mostly in the lower half; three blurred sine bands with thin bright crests stand in for Worldscape's silk folds; a tiled noise image adds grain; the top is darkened for the headline. A full drift takes about a minute. While analyzing, the light brightens and runs about twice as fast, easing back after; Reduce Motion shows one still frame. `Widget/WispField.swift` is widget-only and built for the island, so nothing was reused from it. Worldscape was read, not edited.
- Checks: `scripts/typecheck.sh` passed (app and widget), `check_docs.py` passed. Not run on a device or simulator: the look, speed and frame cost are unseen.
