# Not Yet: hackathon starter

Double-tap the back of your iPhone on any product. A Live Activity shows "Checking…", then flips
to a verdict (Buy now / Wait / Fake deal). Tap it for the full report: price history, when to buy,
where to buy. Save it and get a reminder on the buy date.

Built for **no paid Apple Developer account**: no remote push anywhere. The Live Activity is
started and updated by the app's own Shortcuts action, and reminders are local notifications.

## How it flows

1. Back Tap runs the shortcut: Take Screenshot, Resize Image, then the app's **Check Price** action.
2. Check Price starts the Live Activity (progress bar animates by itself), uploads the screenshot to
   `POST /scan`, and waits up to 25 s for the **quick pass** (identify product + live prices).
3. It updates the Live Activity with the one-liner and an alert (the Dynamic Island expands).
4. Convex keeps running the **deep pass** (Wayback history + dated deal posts, then verdict rules,
   store pick and copy). Results land in the `scans` table.
5. Tapping the Live Activity opens `notyet://scan/<key>`; the app polls `GET /scan?key=` and shows
   the full report.
6. "Save and remind me" stores the item and schedules a local notification for the buy date.

Same product scanned again within 24 h comes straight from the `products` cache in a few seconds.
**Before the demo, scan each hero product once to warm the cache.**

---

## Backend person: Convex (about 15 minutes)

```bash
mkdir notyet-backend && cd notyet-backend
npm init -y && npm i convex
npx convex dev            # log in, create a project, leave it running
# copy everything in convex/ from this folder into ./convex (keep the generated _generated/ folder)
npx convex env set OPENAI_API_KEY sk-...
npx convex env set OPENAI_MODEL <your best vision + web search model>
npx convex env set OPENAI_FAST_MODEL <a fast, cheap vision model>
```

Your HTTP base URL is shown in the Convex dashboard and ends in **.convex.site**. Test it:

```bash
curl -X POST https://YOUR-DEPLOYMENT.convex.site/scan \
  -H "Content-Type: image/jpeg" -H "x-scan-key: test1" --data-binary @screenshot.jpg
curl "https://YOUR-DEPLOYMENT.convex.site/scan?key=test1"   # repeat until status is "done"
```

If OpenAI rejects the `web_search` tool, change `WEB_SEARCH` in `convex/openai.ts` to
`[{ type: "web_search_preview" }]`.

Endpoints (all on your .convex.site URL). New in v3: `GET /discover?kind=lowest|deals`, `POST /recheck`
(runs the daily re-check of tracked items now; it also runs every day at 7 AM Pacific from `crons.ts`).

Endpoints:
`POST /scan` (screenshot body) · `GET /scan?key=` (full report) · `POST /ask` (`{"q": "AirPods Pro 3"}`, used by the
Search tab and the iMessage agent) · `GET /history?deviceId=` · `POST /wishlist` · `GET /wishlist?deviceId=`

Files: `schema.ts` tables · `http.ts` endpoints · `agent.ts` quick pass and deep pass ·
`verdict.ts` all the math and rules (no model calls) · `wayback.ts` archive history ·
`openai.ts` API wrapper · `scans.ts`, `products.ts`, `wishlist.ts` data access.

Tune thresholds in `verdict.ts`. Event dates live in `PAST_EVENTS` and `UPCOMING` there too.

## iOS person: Xcode (about 30 minutes)

1. **New project**: iOS App, SwiftUI, name `NotYet`. Deployment target iOS 17 or later.
2. **Signing**: Signing & Capabilities, Team = your Personal Team (free Apple ID). Pick a unique
   bundle ID once and don't change it (free accounts get a small weekly quota of app IDs).
3. **Add the widget extension**: File, New, Target, Widget Extension, check **Include Live Activity**.
   Delete the template's sample widget files and its bundle file.
4. **Add these files**:
   - Everything in `Shared/` (`ScanAttributes.swift`, `CancelScanIntent.swift`) with target membership **both** app and widget.
   - Everything in `App/` and `Views/` to the **app** target (replace the template `NotYetApp.swift`, delete `ContentView.swift`).
   - Everything in `Widget/` to the **widget** target.
5. **App target Info**: add `Supports Live Activities` (NSSupportsLiveActivities) = YES,
   `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` (the mic in Search crashes without them).
   Under URL Types add scheme `notyet`. Deployment target iOS 18 or later (the tab bar uses the iOS 18 Tab API).
6. Paste your Convex URL into `ScanAPI.baseURL`.
7. **Run on the iPhone**: plug in, enable Developer Mode (Settings, Privacy & Security), and if asked,
   trust your developer profile in Settings, General, VPN & Device Management.

## The shortcut (5 minutes, on the demo phone)

In the Shortcuts app, new shortcut named **Not Yet**:
1. **Take Screenshot**
2. **Resize Image**: width 1200
3. **Check Price** (from the NotYet app): set Screenshot to *Resized Image*

Then Settings, Accessibility, Touch, Back Tap, Double Tap, **Not Yet**. Run it once from inside
another app so any one-time permission prompts appear now and not on stage. Share it as an
iCloud link for onboarding later.

## Product and data person

- Pick 5 or 6 hero products people want this week. Screenshot their retailer pages.
- Run each through `curl` (above) and check the history and verdict look right. Hand-fix bad
  history points in the Convex dashboard if needed, then scan again on the phone to warm the cache.
- Backtest: hide the last few months of a product's history, run `decide()` on the rest, and
  compare to what actually happened. Use your real number in the pitch.
- Replace `HomeView` and `ScanDetailView` with the real design. The data model is in `Models.swift`, and
  `SampleData.swift` has mock data so every screen works in Xcode Previews before the backend is ready.

## Known limits (say them if asked)

- The app's Shortcuts action only gets a short background window, so the pop-up shows the quick
  verdict. If that times out, it says "Still digging, tap to see your verdict" and the app shows the
  full report when opened.
- Wayback coverage is patchy for less popular products; dated deal posts fill the gaps.
- Free signing expires after 7 days. Fine for a demo.
