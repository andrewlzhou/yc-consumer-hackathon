# iPhone app integration status (resume here)

- Goal (CON-14): store screen -> Back Tap -> Shortcut -> on-device text reading -> live backend -> one-word verdict ->
  More Details -> the Check Price app. Ruhaan, 2026-11-15: reaching the app is enough for now; the exact report is a bonus.
- On `main` since PR #2, with the owner's redesigned screens since 90edc6c. Source owner: YCCO-13. Device tests: YCCO-10
  on Ruhaan's Mac and iPhone. Nobody merges without Ruhaan. App rules: [ios/AGENTS.md](../../ios/AGENTS.md).

## Works (unit tests and a cloud simulator with a mock backend, fake key)

- Shortcut actions "Scan Screen with Check Price" and "Check Price of Link" (iOS 26+) return a decision-only popup:
  BUY, WAIT, LOOK ELSEWHERE or INDETERMINATE on the verdict colour, each with a blue More Details button.
- A tap on the popup opens Check Price on that check's thread; the popup stays on top until Done is tapped. Checks
  are saved on the phone, so this also works when iOS closed the app in between.
- A failed check or a missing key shows the failure, never a demo verdict.
- The report draws only the checked product's own data; see "How a check and its report fit" below.
- The temporary screenshot is deleted only from this app's temp or cache folder or Shortcuts' `/var/mobile/tmp`.

## Not proven yet

- On a real iPhone (installed as `dev.ruhaan.checkprice`): Back Tap, the popup, More Details, file deletion, timing.
- iOS adds its own Done button under a result popup. Apple documents no way to rename or remove it. A different
  popup type (a confirmation, `requestConfirmation(actionName:snippetIntent:)`) lets the app name the system button;
  it would change the flow (cancel instead of Done) and is untried.

## How a check and its report fit

- `GET /report` describes the product: its history, and its newest analysis from any scan on any phone.
- So a thread keeps what its own check saw and was told. The report adds the price history. Its verdict, reason and
  forecast are used only when its `scanPrice` equals this check's price (or both have none).
- A link has no price of its own: today's price comes only from the same store's chart line, seen in the last 7 days.
  Otherwise the price row and chart stay empty rather than show another store's or an old price as today's.

## Device test (YCCO-10)

1. Pull `ruhaan_ios_bridge`; keep the real key only in the git-ignored `ios/Config/Secrets.xcconfig` on the Mac.
2. `cd ios && xcodegen generate`, then build and run a Debug build on the iPhone with local signing.
3. Shortcuts: Take Screenshot, then Scan Screen with Check Price, its Screenshot field set to the Screenshot variable (long-press
   the field if it says Choose), Show When Run on. Back Tap runs it. Worth It's own action is a different one.
4. On a store product page, double-tap the back. Expect a coloured one-word popup with More Details; tap it.
5. Read the proof: `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier <bundle id>
   --source Library/Preferences/<bundle id>.plist`, key `checkprice.scans`. Each run has `fileKind` (expect
   `shortcutsTemp`), `deleted` (expect true), `bytes`, and `ocr`, `network`, `total` seconds. Key `checkprice.opens`
   gains an entry each time a More Details tap reaches the app (`found`: its check was still there).

## Known limits (honest list)

- Backend scan fixes are on `main` (a0146e1); YCCO-12 owns deploying them. With them, a screenshot of a product the
  backend doesn't know gives INDETERMINATE; More Details then opens a thread with the verdict and no chart.
- Demo threads still sit in Threads and Home next to real checks, unlabelled; chat replies are canned.
- A finished report without a chart, or six failed fetches, leaves the thread with its verdict and no chart.
- Saved state is not kept across restarts. Report freshness uses a fixed 7-day window.
- The popup shows no reason. The in-app check (and its island) was removed from Home (owner, 2026-11-15); the island now plays only from `-demoLiveActivity YES`.
- Simulator runs can't prove Back Tap or where a real iPhone puts the screenshot file (there it is `other`, kept).

## Checks

- App tests: `xcodebuild test -project CheckPrice.xcodeproj -scheme CheckPrice -destination 'platform=iOS
  Simulator,name=iPhone 16,OS=26.5' CODE_SIGNING_ALLOWED=NO`. Package tests: `cd ios/ShopperKit && swift test`.
- Cloud builds use no key, or a fake key with a mock backend passed as `CHECKPRICE_BACKEND_HOST` and
  `CHECKPRICE_API_KEY` build settings. Never a real key.
