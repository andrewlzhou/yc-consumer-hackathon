# iPhone app: build and run

- Code: `ios/` (XcodeGen `project.yml`, app in `ios/Shopper`, logic and tests in `ios/ShopperKit`).
- App name on the phone: "Worth It". iOS 26 deployment target, SwiftUI, App Intents.

## Build

- Mac: Xcode 26.3+ (the last that runs on macOS Sequoia) and `brew install xcodegen`.
- `cd ios && cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig`, fill in the dev key, your team id and
  a unique bundle id (free Apple ID teams need one). The file is git-ignored; never commit it.
- `xcodegen generate && open Shopper.xcodeproj`, pick the phone, Run. First run on a phone: Settings > Privacy &
  Security > Developer Mode on, and trust the developer under Settings > General > VPN & Device Management.
- Cloud check without a Mac: Revyl's runner builds for the simulator with
  `xcodebuild -scheme Shopper -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build` (Xcode 27).
- Logic tests: `cd ios/ShopperKit && swift test` (works with Command Line Tools only).

## Use

- Back Tap: Shortcuts > new shortcut: Take Screenshot, then Check Price in Screenshot (Worth It). Then Settings >
  Accessibility > Touch > Back Tap > Double Tap > that shortcut.
- Share links: a shortcut with Check Price of Link, "Show in Share Sheet" on, receiving URLs.
- In the app: Check (paste a store link, or pick a screenshot to test the same on-device pipeline), Watchlist
  (swipe to edit target and alerts or remove), Inbox (alerts from monitoring; Mark all read), Setup (device id,
  key present or not, measured p50/p95 times, Foundation Models availability).

## How a screenshot check works

- The intent reads the image bytes, runs Vision OCR and the rules ([extraction](extraction.md)), and sends only
  title, store and prices (or pruned lines when no title was read) to `POST /analyze`. If Shortcuts hands over a
  temp file, the intent deletes it after reading, success or failure.
- It answers with a compact snippet only: a colored word (BUY, WAIT, LOOK ELSEWHERE, INDETERMINATE), one short
  reason line and "sample" when evidence is sample data. It runs in the background; on the real phone the store app
  stays in front and the result shows as a system popup whose outer size iOS decides. Full details stay in the app.
- Foundation Models are tried only when Apple Intelligence is available and the rules missed a field; the model's
  answer is kept only if its title is on screen and its price was also parsed. Ruhaan's A15 iPhone can't run it.

## Keys and auth

- Debug builds read the shared `x-api-key` from Info.plist, filled from `Secrets.xcconfig`; Release builds
  carry none. Anyone can extract a key from a shipped app: a release needs device-bound auth on the backend.
