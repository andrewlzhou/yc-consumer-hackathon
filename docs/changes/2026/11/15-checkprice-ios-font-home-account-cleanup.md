# 2026-11-15 Check Price iPhone: Hiragino font fix, Home and Account cleanup

- Author: Claude (Opus agent, one of three cleanup agents), for Andrew.
- Instructions: "Apply the Worldscape font — why are we using an AI prose font? Get rid of unnecessary items … if it can be described and shown more simply then do that. Don't add random stuff." Lasting rules are in `ios/AGENTS.md` (Design rules).
- Font: the app rendered SF on device. `Typography.swift` looked Hiragino up by family name at runtime and asked for W4/W5, which iOS lacks. It now names `HiraginoSans-W3` (regular, medium), `-W6` (semibold), `-W7` (bold) directly.
- Home: removed the tap icon, the Double-tap paragraph, "Screenshot captured", the step lines, "You can keep scrolling…", the reveal's verdict symbol and arrow, the Summary/Verdicts/Recent labels and the "Estimated" footnote. "Try the reveal" is "Check price", "See the signal" is "Details", "Watching" is "Saved". Each phase is centred on the first screen, which now ends at the tab bar's top edge; the scroll has bottom room. The island gets a short reason ("~$40 less by Cyber Monday").
- Account: removed the "Your name" placeholder, the shelf tab words (icons only), the empty-shelf lines, settings section labels, "Not connected yet" rows and footnote, Notifications and Privacy rows; settings rows are one word. Back button is the chevron alone; Cancel/Done use Hiragino.
- Checks: `xcodegen generate`, `scripts/typecheck.sh` (app and widget ok), `scripts/check_docs.py`. Not run on a simulator or device; no screenshots.
- Next: look on a device at Hiragino's line heights and the centred first screen.
