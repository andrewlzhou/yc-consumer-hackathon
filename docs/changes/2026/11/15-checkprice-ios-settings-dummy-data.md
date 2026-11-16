# 2026-11-15 Check Price iOS: fuller Settings with dummy data

- Author: Claude agent (Opus), for Andrew.
- Instructions: owner asked for dummy data in Settings, more sensible settings, and a profile photo with name and email. The Account line in `ios/AGENTS.md` now describes the page; dummy data is marked in code.
- Changed: the profile card shows a round photo, "Alex Rivera" and "alex.rivera@example.com" (a fictional persona, used until the user saves their own name). Edit profile gained an email field and shows the photo.
- Changed: new cards: plan (Check Price Plus, 12 of 50 checks), Shopping (Region, Currency, Preferred stores, price-drop threshold, each a pushed choice list with checkmarks), Notifications (three toggles, quiet hours), App (Appearance, Haptics, Shortcut, Back Tap, App language), About (privacy, terms, version) and a Sign out row that does nothing yet. Toggles and choices are kept on the device.
- Photo: Unsplash, https://images.unsplash.com/photo-1500648767791-00dcc994a43e (cropped to 300px on the face), under the Unsplash License (free to use, no attribution required). Photographer not checked.
- Checks: `ios/scripts/typecheck.sh`: app and widget ok. `python3 scripts/check_docs.py` run. Not built for iOS or run; nothing seen on screen.
- Next: judge row spacing, the long "Alert me when price drops" row on small phones, and the pushed lists (no title, back button only, per the no-titles rule) in the simulator. `ProfileAvatar` is no longer used anywhere.
