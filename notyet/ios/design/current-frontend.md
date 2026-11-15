# Not Yet iOS: what the frontend is today

Snapshot of `notyet/ios/` as adi j. built it (one commit, "Add Not Yet iOS UI and screenshot workflow"),
written before the restyle. Read from code only: nothing here was built or run (no Xcode on this machine).
"New backend" means `origin/ruhaan_backend` (`convex/lib/contract.ts`, `docs/backend/`).

## 1. Screens and navigation

Root: `Views/RootTabView.swift`, an iOS 18 `TabView` with four `Tab`s, dark mode forced, tint `Theme.prussianLight`.

| Screen | File | What it shows |
|---|---|---|
| Home tab | `Views/HomeView.swift` | The newest history item as a full report (`ReportLoader`). Empty state: "Tap the back of your phone on any product." plus "Check a screenshot". Top-left photo picker. |
| History tab | `Views/HistoryView.swift` | Sort menu, filter chips (All, Tracking, Buy, Wait, Fake), sections Today / Last 7 days / Earlier, `HistoryRow`s. Pull to refresh. |
| Account tab | `Views/AccountView.swift` | Editable name (`@AppStorage("profileName")`), Checked and Tracking counts, "Upgrade to Pro" link. |
| Search tab (`role: .search`) | `Views/SearchView.swift` | Discover rows (Lowest prices, Best deals), bottom "Ask about any product" bar with mic (`Views/VoiceInput.swift`). |
| Discover list | `DiscoverListView` in `SearchView.swift` | Pushed from Search. Product, price, "N% off usual". Row pushes a report with `scanKey: nil`. |
| Report | `Views/ProductReportView.swift` | Verdict panel, prices, chart (`Views/PriceChartView.swift`), tracking, summary, store. |
| Loading / error | `Views/ReportLoader.swift` (`ReportLoader`, `DiggingView`) | Polls a scan by key, then swaps in the report. |
| Settings sheet | `Views/SettingsSheet.swift` | Gear on every tab (`.settingsButton()` in `Theme.swift`). Shortcut link, Back Tap hints, test reminder. |
| Live Activity | `Widget/ScanLiveActivity.swift` | Lock Screen banner and Dynamic Island: "Digging…" then the verdict. |

Navigation
- One global report sheet in `App/NotYetApp.swift`, driven by `Router.shared.openKey`. Setting that key anywhere opens
  `ReportLoader(key:)` in a sheet with a "Done" button. History rows, Search results and "Check this for me" all use it.
- Deep link `notyet://scan/<scanKey>` (`Router.handle`). Opening it also ends every running Live Activity.
- Tapping a buy reminder notification sets `openKey` from `userInfo["scanKey"]` (`AppDelegate`).
- Mock keys (only while `ScanAPI.baseURL` still contains `YOUR-DEPLOYMENT`): `a` or any other key = Wait report,
  `b` = Fake deal, `c` = Buy, `digging` = never finishes. A new key digs for 4 seconds, then shows the Wait report.

Launch arguments
- `-startTab home|history|account|search`: read through `UserDefaults` in `RootTabView`.
- `-screenshots`: skips the notification permission prompt (`NotYetApp`).
- `-scrollBottom`: the report starts scrolled to the bottom (`ProductReportView`).

## 2. The purchase-request flow

There are three ways in. All end at the same report.

A. Back Tap shortcut (the main one; runs with the app closed)
1. Shortcut: Take Screenshot, Resize to 1200 wide, then the app's "Check Price" action: `App/CheckPriceIntent.swift`.
2. The intent ends any old Live Activity, makes a `scanKey` (UUID), and starts a Live Activity in stage `working`:
   headline "Finding the product…", a progress bar that fills on its own over 14 seconds, an X that runs
   `Shared/CancelScanIntent.swift`.
3. It re-encodes the image as JPEG (quality 0.7) and calls `ScanAPI.submit(..., timeout: 25)`: the quick pass.
4. Success: stage `ready`. The activity shows the verdict word, the one-liner, the retailer pill and a dollar icon,
   with an alert (sound, Dynamic Island expands).
5. Failure or timeout: stage `failed`, "Still digging. Tap to see your verdict.", word "Tap to open", grey magnifier.
6. Tapping the activity opens `notyet://scan/<key>`, which opens the report sheet (step D).

B. Screenshot picked in the app (`HomeView.check`)
- Sets `router.openKey` first so the sheet opens straight away, then calls `submit(..., timeout: 60)` and discards the result.

C. Typed or spoken question (`SearchView.ask`)
- Waits for `ScanAPI.ask(q)` (40 second timeout) with only a small spinner in the ask bar, then opens the sheet.
- Failure: one red line, "Try the exact model name."

D. Report sheet (`ReportLoader`)
- Polls `ScanAPI.fetchScan(key:)` every 2 seconds, up to 150 times (5 minutes).
- `status` "working" or "deep", or no answer yet: `DiggingView`. Animated square scanner, "Digging…", the server's
  `step` text (default "Starting…"), and the quick one-liner once `quick` exists. This is the only place the
  quick pass shows inside the app.
- `status` "done" with a `result`: `ProductReportView`.
- `status` "error": "No product found" (only for that exact error string) or "Couldn't finish this check", plus
  "Try the product page or the exact model name." No retry button.

E. Report (`ProductReportView`, top to bottom)
- Product name; verdict panel ("Verdict" + Buy / Wait / Fake deal in the verdict color, bouncing dollar sign,
  one-liner); Current price; Projected price with "by <date>" and an up or down arrow; "Last 12 months" chart
  with a dashed Today line and a dashed projection; tracking; summary; store.
- Summary: "Searched N sources and X of price trends." then `tldr`.
- Store: "Buy at <retailer> <totalCost>", "Avg review" stars, "Open on <retailer>" link.

F. Save and remind (`ProductReportView.track`, `App/Reminders.swift`)
- "Need it by" chips: 1 week, 2 weeks, 1 month, 3 months, stored as `@AppStorage("defaultNeedByDays")` (default 30).
- "Track until I need it" calls `ScanAPI.saveToWishlist(key:needBy:)`, then schedules a local notification for 9 AM
  on `waitUntil` if that is on or before the need-by date, otherwise on the need-by date. Button becomes "Tracking daily".
- A date that is missing or in the past fires the reminder in 10 seconds (intended for the stage demo).
- Long-press the button: "Demo: remind me in 10 seconds".
- Opened from Discover (`scanKey == nil`): the tracking block is replaced by "Check this for me", which runs
  `ScanAPI.ask(product name)` and opens the new scan.
- History row "…" menu: Open, "Track this price" (saves with no date and no reminder), Share.

Sample data
- `ScanAPI.useMocks` is true until the base URL is replaced; every call then returns `App/SampleData.swift`.
- Nothing on screen says the data is sample data.

## 3. Contracts that must not break

`App/Models.swift` (decoded from the current starter backend in `notyet/convex/`; fields may only be added as optionals)
- `ScanResponse { status, step?, quick?, result?, error? }`, status "working" | "deep" | "done" | "error".
- `QuickInfo { productName?, verdict?, oneLiner? }`.
- `FullResult { product{name, brand?, model?}, verdict, oneLiner, confidence, currentPrice, expectedPrice{low, high}?,
  waitUntil?, whereToBuy{retailer, price, totalCost, url, reason?}?, history[Point{date, price, retailer?, source}],
  tldr, projectedPrice?, sourcesChecked?, yearsOfData?, avgRating?, reviewCount? }`.
- `HistoryItem { scanKey, status, createdAt (ms), productName?, verdict?, oneLiner?, retailer?, currentPrice?, saved?,
  needBy?, lastPrice?, dropped? }`; `WishlistItem`; `DiscoverItem { key, discount, result }`.
- Verdict strings the UI understands: `BUY_NOW`, `WAIT`, `FAKE_DEAL`. Dates are "YYYY-MM-DD".

`App/ScanAPI.swift` signatures
- `submit(imageData: Data, scanKey: String, needBy: String? = nil, timeout: TimeInterval) async throws -> Quick`
- `fetchScan(key: String) async throws -> ScanResponse`
- `ask(_ q: String, needBy: String? = nil) async throws -> Quick`
- `fetchHistory() -> [HistoryItem]`, `fetchWishlist() -> [WishlistItem]`, `fetchDiscover(kind: String) -> [DiscoverItem]`
- `saveToWishlist(key: String, needBy: String? = nil)`
- `Quick { scanKey, productName, verdict, oneLiner, retailer? }`; also `baseURL`, `useMocks`, `deviceId`.

`Views/Theme.swift` names used across views
- Colors: `paper`, `ink`, `slate`, `hairline`, `prussian` (#003153), `prussianLight` (#4A86BD), `buy` (#3DDC97),
  `wait` (#FFB547), `fake` (#FF5C5C).
- Helpers: `display(_:)` (BricolageGrotesque-Bold; the font file is not in the repo, so it falls back to the
  system font), `money`, `day`, `dayString`, `productSymbol`.
- Shared pieces: `VerdictStyle`, `SharpButtonStyle`, `Chip`, `RetailerBadge`, `StarsView`, `Hairline`,
  `.settingsButton()`, `Config.shortcutURL`, `Config.proCheckoutURL` (both placeholders).

Widget and Live Activity
- `Shared/ScanAttributes.swift` (both targets): `ContentState { stage, headline, productName?, verdict?, scanKey,
  etaEnd, retailer? }`, `startedAt`. Stage is "working" | "ready" | "failed".
- `Shared/CancelScanIntent.swift` (both targets). `CheckPriceIntent` is the Shortcuts action; its title "Check Price"
  and its `Screenshot` parameter are what the user's shortcut is wired to.
- The widget cannot see `Theme`, so `ScanLiveActivity.swift` has its own copies of the five colors. A palette change
  has to be made in both places.
- `project.yml` builds the app (`App`, `Views`, `Shared`) and embeds the widget extension `NotYetWidgets` (`Widget`, `Shared`,
  bundle id `com.notyet.ui.widgets`). `-demoLiveActivity YES` starts the pop-up without a Shortcut. CI does not screenshot it.

CI screenshots (`.github/workflows/ios-screenshots.yml`)
- Runs on pushes touching `notyet/ios/**`. XcodeGen project `NotYetUI`, scheme `NotYetUI`, bundle id `com.notyet.ui`,
  dark appearance, then force-pushes PNGs to the `screenshots` branch.
- Shots: `01-home`, `02-home-bottom` (`-scrollBottom YES`), `03-history` (`-startTab history`), `04-search`,
  `05-account`, `06-report-fake-deal` (`notyet://scan/b`), `07-...-bottom`, `08-report-buy` (`scan/c`),
  `09-digging` (`scan/digging`). Every launch passes `-screenshots YES`.
- So these must keep working: the three launch arguments, the `notyet://scan/<key>` link, mock mode, and the mock
  keys `b`, `c`, `digging`.
- The build step does not fail on compile errors by itself; it only checks that the `.app` exists.

## 4. adi's rules and the sketches

Rules in `UI_WORKFLOW.md`
1. Black background, white text, Prussian blue (#003153), colors through `Theme` tokens only.
2. Square corners. No `RoundedRectangle`, `Capsule` or `Circle` in `Views/`.
3. As little text as possible. No explanations where a label or number does the job.
4. Only edit `Views/` (and `App/SampleData.swift` for more sample states). Do not change `Models.swift` or
   `ScanAPI.swift` signatures.

`notyet-preview.html` is a browser copy of the same screens, each block labeled with the Swift view it mirrors, with a
"Simulate back tap" button for the Dynamic Island. It carries no extra design intent beyond the Swift code.

Sketches (`sketches/`)
- `popup.png`: trigger is Back Tap or the Action Button over a store page. While searching, a pill with a radar-like
  icon, "Digging…" and an X to cancel. Result pill: dollar sign, "Buy", store name. Notes: the dollar sign should
  "pop up like in Shazam"; "every search gets added to history".
- `report.png`: "Verdict: BUY" boxed at the top and marked green; Current and Projected (with arrow); "Last 12 months"
  chart with a dashed Today line and room to the right for the future; the page scrolls. Lower half: "[Sample]
  Searched X sources and dug through X years of trends to find you the best deal", "Buy at: Amazon", product link,
  average review stars. Tab bar: Home, History, Account, and a separate round search button.
- `history-search.png`: History with a settings gear, a sort icon and filter chips, day sections, rows with product
  icon, name, date, a "…" menu and a store icon; a marker on tracked rows meaning "every day: search and price
  update until needed date". Search: "Discover" with "Lowest Prices" and "Best Deals", an "Ask…" bar with audio.

What a restyle would override
- Rules 1 and 2 are the ones a new design language replaces (palette, square corners). The sketches themselves draw
  rounded pills and chips, so square corners come from the written rule, not from the sketches.
- Rule 3 (few words) and rule 4 (leave `Models` and `ScanAPI` alone) are independent of styling.
- Layout intent that both the sketches and the code agree on: verdict first and color-coded, two prices, one chart,
  history grouped by day with filters, Discover plus an ask bar, the Digging-then-dollar pop-up.

## 5. Gaps

### Facts: what the new backend sends that the UI has no place for
- Verdict set differs. New backend: `BUY_NOW`, `WAIT`, `CONSIDER_ALTERNATIVE`, `INVESTIGATE`. The UI has no
  `FAKE_DEAL` equivalent arriving and no case for the two new values: `VerdictStyle` would show them as grey
  "Checking", the Live Activity as "Tap to open", and the History "Fake" chip would always be empty.
- `isSampleData` (on the verdict, the chart and the analysis). The contract says the phone must label it. No label exists.
- `confidence` (0 to 1). `FullResult.confidence` is already decoded today and never displayed.
- `matchedTitle` ("we think this is ...") and `match.note`. The UI shows a product name with no hint it was a guess.
- `reportStatus` / `pending`: quick verdict now, fuller analysis later. The closest thing today is "deep" + `quick`.
- Forecast: `low`, `high`, `byDate`, `outlook`, `eventName`, `pastEditions`, `savingsAtLow` and percent. The UI shows one
  projected number; today's `expectedPrice` range is averaged into a midpoint.
- Discount check: `discount.status` (genuine, misleading, none claimed, unclear), `signals`, claimed versus real
  discount percent, how often the "was" price was actually charged, pre-sale price hikes. Not shown anywhere.
- Alternatives: `competitors` and `competitorComparison` (price gap, savings percent, spec table). No screen for them,
  and `CONSIDER_ALTERNATIVE` cannot be explained without them.
- Chart: one step series per retailer, `lowest` (price, date, retailer), `typicalPrice`, sale `events` to shade,
  point counts by source. Today's chart is one line with no low, typical or event marks.
- Per-retailer patterns (typical, lowest, sale count and depth, last sale), and written sections
  (`priceAssessment`, `retailers`, `recommendation`) with evidence ids.
- Watchlist inbox: `GET /watchlist/notifications` with a `trigger` (target hit, new low, sale start, better alternative).

### Facts: transport differences that affect the flow
- New backend takes `POST /analyze` with extracted fields (title, price, was-price, retailer, url, `ocrLines`) and never
  the screenshot; the app today uploads the JPEG and has no on-device text reading.
- It is keyed by `productId`, not a client-made `scanKey`; reports come from `GET /report?productId=`.
- It needs an `x-api-key` header and a `deviceId`; errors are 400, 401, 429 (rate limited), 500.
- No `/scan`, `/ask`, `/history` or `/discover` routes exist there. Saving is `/watchlist/save`. History, Discover,
  free-text ask, `whereToBuy`, ratings, `sourcesChecked` and `tldr` have no direct counterpart in the files I read.

### Facts: friction in the current flow
- Fields decoded but never shown: `confidence`, `expectedPrice` range, `whereToBuy.reason` and `price`, `reviewCount`,
  `product.brand` / `model`, each history point's `source` and `retailer`, `HistoryItem.currentPrice` / `lastPrice`.
  `fetchWishlist` and `WishlistItem` are not used by any view.
- History rows show the verdict only as a 3-point colored bar; the verdict word and one-liner are not on the row.
- The report does not know an item is already tracked (`tracked` is local state), so a tracked item reopens with
  "Track until I need it" enabled.
- `track` ignores a failed save and still shows "Tracking daily". If notifications are denied, no reminder is set and
  nothing says so.
- For a Buy verdict (`waitUntil` nil) the reminder still fires "Time to buy" on the need-by date.
- The picked-screenshot path discards upload errors; with no network the sheet shows "Digging… Starting…" for
  5 minutes, then stays on it with polling stopped.
- Search waits up to 40 seconds behind a small spinner before anything opens. "Check this for me" disables its
  button with no spinner and fails silently.
- The error screen has no retry or close-and-try-again action beyond "Done".
- Home is titled "Home" and is the last report; starting a new check from inside the app is an unlabeled icon.
- The Live Activity bar always fills in 14 seconds while the wait can be 25; the `failed` stage reads like progress.

### Judgment (opinion, not fact)
- The verdict mismatch is the first thing to settle: without new styles and words for `CONSIDER_ALTERNATIVE` and
  `INVESTIGATE`, half of the new backend's answers render as "Checking".
- The verdict panel answers "what" but not "how sure" or "why". Confidence, the forecast range with its date, and the
  discount status are the three additions most likely to make the verdict believable; all fit adi's few-words rule
  as numbers or one-word labels.
- A sample-data label is a contract requirement, not a styling choice, and should be designed in from the start.
- The quick verdict deserves a real state in the app (verdict and reason now, "full report loading" below), instead
  of one line under the Digging animation.
- Keeping `Models.swift` and `ScanAPI` signatures while switching backends probably means an adapter inside `ScanAPI`
  plus new optional fields; where the product text gets read from the screenshot is an open decision for the team.
