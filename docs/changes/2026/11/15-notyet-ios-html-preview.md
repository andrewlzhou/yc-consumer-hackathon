# 2026-11-15 — Not Yet iOS: HTML preview in the Worldscape style

- Author: Claude (Opus 5.5) subagent, requested by Andrew through a coordinating agent.
- Instructions: no new lasting guidance. Task constraint: edit only `notyet/ios/notyet-preview.html` and this note, while five other agents restyle the Swift screens.
- Changed: rebuilt `notyet/ios/notyet-preview.html` to mirror the restyled Swift screens: report (verdict hero, price, chart, why, alternatives, need-by tracking, where to buy, sample-data footer), digging steps and first look, problem states, Home (latest and empty), History, Search (asking, failed), Discover, Account, Settings, tab bar, Dynamic Island and Lock Screen Live Activity. Data is `App/SampleData.swift` (keys a-e). `?bare` shows the phone alone; `?state=<name>` opens a state.
- Checks: rendered 33 states in headless Chromium (Playwright) at 402x874 and looked at each; no page errors. This is a browser approximation (hand-drawn SF Symbols, Swift Charts, materials, mesh gradient), not a SwiftUI render.
- Next: confirm on a device or in CI screenshots. Two things the preview shows that will likely look the same on the phone: Hiragino draws "…" as centred dots ("Hea···"), and in `SampleData.make` reports the history (current × shape) dips below the `lowest` price the report states, so the chart's low marker sits off the line.
