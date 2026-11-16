# 2026-11-15 — Check Price: screenshot action renamed; More Details on every verdict

- Author: Capy (Fable 5.2), thread YCCO-13 for Captain Ruhaan (CON-18), branch `ruhaan_action_rename`, PR #4.
- Instructions: Ruhaan: (1) the Check Price app's screenshot action must not share a name with the Worth It test
  app's; it is titled exactly "Scan Screen with Check Price". (2) Reduced acceptance for now: double tap gives the
  verdict word, and More Details gets into the Check Price app; exact report behaviour inside the app is not
  required. The four words stay. Saved in [ios/AGENTS.md](../../../../ios/AGENTS.md),
  [decisions](../../../project/decisions.md) and [status](../../../ios/bridge-status.md).
- Changed: the action's title (same action type, so existing shortcuts keep working). More Details is now on every
  verdict; before, a check the backend matched to no product had no button, so the popup had no way into the app.
  The tap opens the app and that check's own saved thread (by the check's id, not the product's). Debug builds note
  each tap that reaches the app under `checkprice.opens`. No layout, backend or contract change.
- Checks: `python3 scripts/check_docs.py`; app tests and ShopperKit tests on a cloud runner with no key: see the PR.
- Not verified: Back Tap and the tap on a real iPhone (YCCO-10).
