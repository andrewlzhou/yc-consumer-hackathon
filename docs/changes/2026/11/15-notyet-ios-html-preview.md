# 2026-11-15 — Not Yet iOS: HTML preview in the Worldscape style

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: no new lasting guidance. Task constraint: edit only `notyet/ios/notyet-preview.html` and this note, while five other agents restyle the Swift screens.
- Changed: rebuilt `notyet/ios/notyet-preview.html` on the Worldscape tokens and components (Hiragino Sans, keys, glass on the blue backdrop, flat cards, chips, hopping dots, shimmer). It shows every verdict state, the digging and quick-verdict states, the error state, Home, History, Search with the ask bar, Discover, Account, Settings, the Dynamic Island and the Lock Screen Live Activity. `?bare` shows the phone alone; `?state=<name>` opens a state.
- Checks: rendered every state in headless Chromium (Playwright) at 402x874 and looked at each screenshot; no page errors.
- Next: align the preview with each Swift screen as it lands.
