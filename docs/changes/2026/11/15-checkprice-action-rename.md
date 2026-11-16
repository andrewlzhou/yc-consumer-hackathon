# 2026-11-15 — Check Price: screenshot Shortcut action renamed

- Author: Capy (Fable 5.2), thread YCCO-13 for Captain Ruhaan, branch `ruhaan_action_rename` from `main` 90edc6c.
- Instructions: Ruhaan: the Check Price app's screenshot action must not share a name with the Worth It test app's;
  it is titled exactly "Scan Screen with Check Price". Saved in [ios/AGENTS.md](../../../../ios/AGENTS.md) and
  [status](../../../ios/bridge-status.md).
- Changed: the action's title only. Same action type, Screenshot field, check, popup and More Details route; "Check
  Price of Link" keeps its name. An existing shortcut that already holds the action keeps working and shows the new
  title. The status doc's branch line and device steps were brought up to date.
- Checks: `python3 scripts/check_docs.py` passed. Not compiled after this one-string change; `main` 90edc6c built and
  passed 20 app tests and 23 ShopperKit tests on a cloud runner just before it.
- Next: YCCO-10 rebuilds and reinstalls, then one Back Tap on the phone.
