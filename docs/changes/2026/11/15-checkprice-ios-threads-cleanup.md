# 2026-11-15 Check Price iPhone: Threads cleanup

- Author: Claude (Opus agent, one of three in the cleanup pass), for Andrew.
- Instructions: owner: use the Worldscape font; remove anything not needed; no sample-data or prototype text, no "The signal", no "Chat" label, no suggested questions. Pass rule: no explanatory text, disclaimers, section labels that only name a section, helper lines or suggested prompts; a number or a word over a sentence.
- Removed (`ios/CheckPrice/Screens/Threads/`): "The signal" section and its headline/reason text; the sample-data/prototype line; the "Sample data" tag on the verdict; the "Price", "Last 12 months" and "Chat" labels; "Ask anything about this price." and the suggested-question chips; the "under usual" and "save up to" lines; the list row's product tile, retailer and latest-chat line; the empty-state sentences (symbol only now). Save reads "Save" / "Saved" with a bookmark (was a bell and "Save & alert me", which implied alerts that don't exist). Input placeholder is "Ask…".
- Detail now, top to bottom: verdict and reason, today vs expected price (with the expected date when known), the chart, the check time with heart and save, the chat messages, the input bar.
- Font: every `.font(.system(...))` in these files is now `Font.hiragino(...)`.
- Checks: `xcodegen generate` and `scripts/typecheck.sh` passed (app and widget). Not run on a simulator; no screenshots.
- Pending: `SampleDataTag` is no longer used by Threads; its comment says the backend contract requires it, so the owner's removal overrides that. `ios/AGENTS.md` still says section labels like "Price" and "Chat" are fine; it should be updated to match this pass.
