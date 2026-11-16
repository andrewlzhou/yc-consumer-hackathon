# YC Consumer Hackathon

An AI shopping assistant that tells you whether a product is worth buying right now, or whether to wait.

## The idea

- Pricing research for ordinary shoppers. Don't just find out what something costs; find out whether it's worth buying now.
- While looking at a product online, the user opens the assistant (iPhone Shortcut, Control Center button, Safari extension, or share menu). It identifies the product and returns a short analysis:
  - **Price history:** average price, historical low, whether today's price is unusually high or low, and each retailer's discount patterns.
  - **Discount check:** whether the advertised "original" price matches prices actually seen, such as a price raised just before a sale, and why a discount may be misleading.
  - **Alternatives:** similar products from other brands, compared on specs, features, and price.
  - **Forecast:** whether a better price is likely soon (for example, an Apple discount next month), with a predicted range and confidence level.
- Every analysis ends in one verdict: **BUY NOW**, **WAIT**, **CONSIDER ALTERNATIVE**, or **INVESTIGATE** (not enough reliable data).
- **Watchlist:** saved products are watched in the background, and the user gets a push notification when a meaningful opportunity appears. Users set target prices and notification preferences.
- **Detailed report** on request: price chart, retailer and competitor comparisons, discount analysis, predicted price range, and the reasoning behind the verdict.

## Three workstreams

- **Backend:** pull and store historical price data, and compute from it in a mostly deterministic way.
- **Surfacing:** when and how the assistant brings this to the user on its own.
- **UI/UX:** how good the product looks and feels.

## What exists today

- The Convex backend is on `main`: a product title or supported store link returns a verdict card, with a price chart and detailed report available separately.
- A small electronics demo uses real online price history; gaps use clearly labeled sample data. Broader store coverage is still being verified.
- Watchlists, target prices and a notification inbox work. Real iPhone push delivery still needs Apple credentials and a device.
- The iPhone app (`ios/`, Check Price) sends a store link or screenshot to that backend and shows the real verdict and report (2026-11-15). Not yet tried on a phone with the real key.
- [Try the backend now](docs/backend/try-now.md) from a terminal; no app API key is needed for the Convex-authorized internal demo.

## Where this goes

- <!-- TODO: the direction the idea is heading. -->

## Find your way

- `convex/` — the backend: price data, shopping analysis, watchlists and monitoring.
- [Docs](docs/README.md) — setup, module guides, and current decisions.
- [Agent rules](AGENTS.md) — how Codex, Claude, and other contributors should work here.
- [Change history](docs/changes/README.md) — short session notes; full code history lives in Git.

## Start locally

- [Backend setup](docs/backend/README.md) — install packages, then run `npm run dev` once to log in to Convex.
- New agents should start with [AGENTS.md](AGENTS.md). Keep this README current as the premise evolves.
