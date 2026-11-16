# Device test (real iPhone)

- Goal: prove Back Tap -> Shortcut "Take Screenshot" -> our App Intent works inside a store app, without leaving
  it and without saving the screenshot. Results so far are in [status](status.md).

## One-time setup on the phone

1. Install a debug build from the Mac (see [app](app.md)); trust the developer under Settings > General >
   VPN & Device Management.
2. Shortcuts > + > add **Take Screenshot**, then **Check Price in Screenshot** (Worth It). Its Screenshot field
   must be the Take Screenshot result. Name it "Worth It". Leave "Show When Run" off.
3. Settings > Accessibility > Touch > Back Tap > Double Tap > "Worth It".
4. Open Photos > Recents and note the newest item.

## Each run

1. Open a store app (Amazon, Best Buy, Target, Walmart, AE) on a product page: Sony WH-1000XM5, WH-1000XM6,
   AE Baggy Jean, and one product the backend doesn't know.
2. Double-tap the back of the phone and start a stopwatch. Note: did the store app stay in front, what text
   appeared and where, and seconds until the verdict showed.
3. After the runs, check Photos > Recents: no new screenshots should be there.

## What the Mac reads back over USB (no image content)

- `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier <bundle id>
  --source Library/Preferences/<bundle id>.plist`: `shopper.timings` (OCR, network, total per run) and
  `shopper.lastHandoff` (file-backed or in-memory, bytes, whether the file was ours and deleted).
- Debug builds also accept `-checkLink <url>` and `-checkImage <file in Documents>` launch arguments
  (`devicectl device process launch ... <bundle id> -- -checkLink https://...`); results go to
  Documents/debug-runs.json. Release builds have no hook.
