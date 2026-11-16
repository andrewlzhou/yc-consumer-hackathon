# 2026-11-15 — iOS Library: Watchlist toggle on the title line

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: Andrew asked for the watchlist on the right side, without the word "Watchlist". Saved in `ios/AGENTS.md` (Files, `Threads/ThreadsView`).
- Changed: the Watchlist row is gone. A bookmark icon sits at the right end of the "Library" title line, centred with the title, in a 44 pt target lined up with the rows' save buttons. Outline when off; orange filled when on, showing only saved threads. Same in-place filter and animation as before. VoiceOver reads "Watchlist", On or Off, and selected when on.
- Checks: `ios/scripts/typecheck.sh` passed for the app and the widget; `python3 scripts/check_docs.py` passed. Not built for iOS or seen on screen.
- Next: check the icon's alignment with the title by eye on a simulator or device.
