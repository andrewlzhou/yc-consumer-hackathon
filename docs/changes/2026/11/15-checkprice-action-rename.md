# 2026-11-15 — Check Price: action renamed, More Details on every verdict, opt-in canned demo

- Author: Capy (Fable 5.2), thread YCCO-13 for Captain Ruhaan (CON-18), branch `ruhaan_action_rename`, PR #4.
- Instructions (Ruhaan): the screenshot action is titled exactly "Scan Screen with Check Price"; More Details must
  always get into the app; and for the demo the popup may be fixed to green BUY with More Details. Saved in
  [ios/AGENTS.md](../../../../ios/AGENTS.md), [decisions](../../../project/decisions.md), [status](../../../ios/bridge-status.md).
- Changed: the action's title (same action type, so existing shortcuts keep working). More Details is on every
  verdict and opens the app on that check's own saved thread. Debug builds note taps that reach the app
  (`checkprice.opens`).
- Changed: an opt-in canned demo. A Debug build made with the compilation condition `CHECKPRICE_DEMO_BUY` (one line
  in the git-ignored `Config/Secrets.xcconfig`) answers every scan with BUY and More Details: no text reading, no
  backend call, no saved check. Off by default and impossible in Release; the live path is unchanged when it is off.
- Checks: `python3 scripts/check_docs.py`. Before the demo flag: 20 app tests passed on a cloud runner with no key.
  The demo commit was pushed before its own cloud run; see the PR for that result.
- Not verified: a flag-on build, and anything on a real iPhone at this head (YCCO-10). Screenshot cleanup on the
  phone: two real Back Taps on 671b059 classed the file `other`, so the app did not delete it. Next: read the
  file's folder on the device privately and add that exact folder to the allowed roots; no substring matching.
