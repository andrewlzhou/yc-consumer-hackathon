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

- Product idea chosen 2026-11-15. Everything above is the plan; no product features are built yet. The Convex backend is set up and empty.

## Where this goes

- <!-- TODO: the direction the idea is heading. -->

## Find your way

- `convex/` — the backend (Convex). Set up, but nothing built yet.
- [Docs](docs/README.md) — setup, module guides, and current decisions.
- [Agent rules](AGENTS.md) — how Codex, Claude, and other contributors should work here.
- [Change history](docs/changes/README.md) — short session notes; full code history lives in Git.

## Start locally

- [Backend setup](docs/backend/README.md) — install packages, then run `npm run dev` once to log in to Convex.
- New agents should start with [AGENTS.md](AGENTS.md). Keep this README current as the premise evolves.
