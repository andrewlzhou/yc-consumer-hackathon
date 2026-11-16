# 2026-11-15 — iOS Library: verdict badge on each row

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: Andrew asked for a nice-looking sign on the Threads page of whether we recommend buying each product now. Saved in `ios/AGENTS.md` (Verdicts bullet).
- Changed: each Library row's picture carries a small round badge on its bottom-right corner, overlapping the edge: the verdict's symbol in the canvas colour on a disc of the verdict colour, with a 2 pt canvas ring. VoiceOver reads the verdict word with the row. No other row change.
- Changed: Check first is now sand (`#CFC0A3`) instead of coral (`#FF9466`), which was too close to the orange accent used by the saved bookmark on the same row. This also changes Check first on the reveal, the report and Home. The Live Activity wisps (`Widget/WispField.swift`) keep their own coral set.
- Checks: `ios/scripts/typecheck.sh` passed for the app and the widget; `python3 scripts/check_docs.py` passed. Not built for iOS or seen on screen.
- Next: judge the badge size, overhang and the sand tone by eye on a device or simulator.
