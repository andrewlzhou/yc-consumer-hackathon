# 2026-11-15 — Compact Back Tap verdict and tap-through to the product's thread

- Author: Capy (Opus 5.5), thread YCCO-13 for Captain Ruhaan (CON-12), branch `ruhaan_ios_bridge` from `main`.
- Instructions: Ruhaan chose compact labels BUY, WAIT, LOOK ELSEWHERE, INDETERMINATE, one per backend verdict
  (saved in [decisions](../../../project/decisions.md) and [ios/AGENTS.md](../../../../ios/AGENTS.md)). No backend or API change.
- Changed: Check Price gained Shortcut actions (screenshot, link; iOS 26) that start a thread and return a compact
  verdict snippet with a blue Details button. Details, and `checkprice://product/<productId>`, open that product's
  thread, building it from `GET /report` after a relaunch. Shortcuts' temporary screenshot copy is deleted after reading,
  tmp/cache folders only (YCCO-10's finding). Existing screens are unchanged; `ThreadStore` got `openProduct`.
- Checks: 10 unit tests (labels, short reason, links, temp-file rule, which thread opens) and a simulator build on
  Revyl (Xcode 27, iOS 26.5). On a Revyl iPhone 16: a Shortcut running Check Price of Link on a real Best Buy AirPods
  Pro 3 link showed the green BUY snippet; Details opened that product's thread. Cold-start link to the real XM5 id
  opened its report; a second open reused the thread; an unknown id opened nothing. Docs check passed.
- Security: the first three Revyl builds uploaded the git-ignored `Config/Secrets.xcconfig` (dev key) and their Debug apps
  carried it. Key removed locally, `ios/.capyignore` now excludes it, later builds use no key; Captain rotates the key.
- Not verified: Back Tap on a real iPhone with this app (screenshot path, temp-file deletion, speed). iOS draws the
  platter and its blue Done button; Done only dismisses and can't be restyled or routed.
