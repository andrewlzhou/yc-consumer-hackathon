# 2026-11-15 — Check Price: redesign merge parked as work in progress

- Author: Capy (Fable 5.2), thread YCCO-13 for Captain Ruhaan (CON-17), branch `ruhaan_ui_refresh-wip`.
- Instructions: Ruhaan first asked to get the new UI on `checkprice-ios` working with the pipeline, then paused it:
  he will say when the redesign is on `main`. No lasting rule; nothing here goes to `main` or a pull request.
- Changed: `main` (eb5c55b) merged with `checkprice-ios` (315d218), conflicts resolved to keep both: the redesign's
  screens and `main`'s Shortcut actions, saved checks and real-check rules. The detail page's Why, Prediction and
  Sources take only real report facts for a real check. Home's check screen is gone, as the redesign removed it.
- Checks: `python3 scripts/check_docs.py`. Not compiled and no tests run: the cloud build was cancelled when the
  work was paused. Treat this branch as unverified.
- Next: when the redesign lands on `main`, redo or refresh this merge from the new heads, then build and test.
