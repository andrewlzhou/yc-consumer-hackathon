# 2026-11-15 Check Price iPhone: Settings like Claude's

- Author: Claude (Opus agent), for Andrew.
- Instructions: owner: the Settings page should look more like the Claude iOS app's Settings. Saved in `ios/AGENTS.md` (Files, Account entry; the no-titles rule now names this sheet's centred title as an exception).
- Changed: the Account gear opens Settings as a sheet instead of pushing it. Top: a round X on the left and "Settings" centred. Then a card with the avatar, name and @handle (handle moves up when there is no name; with neither, only the avatar). Then "Account" (Profile, Notifications) and "App" (Shortcut, Back Tap, Version) cards: thin outline symbols, regular labels, version on the right, separators starting at the labels, fill slightly lighter than the canvas, large corners. Only Profile is a button (opens Edit profile) and only it has a chevron. "Price alerts" is now "Notifications" with a bell. The card and rows stay local to the Settings file, since nothing else repeats them.
- Checks: `scripts/typecheck.sh` passed (app and widget), `check_docs.py` passed. No full Xcode on this Mac, so no simulator build and no screenshots.
- Next: view it on a simulator or device; check that the nested Edit profile sheet opens from inside the Settings sheet.
