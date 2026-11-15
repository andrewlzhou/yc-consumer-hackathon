# Product context (backend view)

- Condensed from Ruhaan's spec 00 (2026-11-15). Context, not a fixed spec: change it when testing shows better.
- An iPhone shopping agent. While shopping in another app (Target, Walmart), the user triggers it and gets a quick verdict
  on whether to buy now; a deeper analysis lives in our app. Saved products are watched in the background.
- Phase: functionality only. A demo that works reliably on a handful of products beats broad, flaky coverage.

## What the backend must do

- Identify the scanned product from a messy title and price (no barcode).
- Price history: averages, lows, whether today's price is unusually high or low, retailer discount patterns.
- Competitors: similar products from other brands, compared on specs and price; cheaper equivalents.
- Discount authenticity: compare the "was" price with prices actually seen; spot pre-sale hikes and fake discounts.
- Forecast: whether a better price is coming, as a range plus a confidence level.
- Exactly one verdict per analysis:
  - BUY_NOW: the current price is an attractive opportunity.
  - WAIT: history suggests a better price is coming.
  - CONSIDER_ALTERNATIVE: a competitor offers better value.
  - INVESTIGATE: not enough reliable information.
- Watchlist: target prices, preferences, push when a real opportunity appears.
- Detailed report data (charts, comparisons, reasoning). Screens come later; the backend produces the data now.

## Architecture in one paragraph

- An LLM agent, not a rules engine. It reasons over evidence it retrieves through tools (RAG + tool use).
- Plain code owns what LLMs are bad at: exact arithmetic (averages, percentiles, lows), storage, scheduling, caching.
- Grounded: every number in a reason traces to a tool result; thin evidence means INVESTIGATE.

## Flow

1. Back Tap runs a Shortcut; Take Screenshot hands the image to our App Intent.
2. The phone reads the screen on-device and keeps only title, price, "was" price, retailer. The image is discarded.
3. The phone POSTs that extract to the backend ([contract](contract.md)).
4. The backend identifies the product, records the price, and returns a verdict, ideally from a prepared analysis.
5. Saved products are re-checked by the monitoring agent, which pushes notifications.

## Hard constraints

- The screenshot never leaves the phone and is never stored.
- Never present invented data as real. Seeded history is tagged `source: "seed"` and labeled as sample data.
- Live path target is about 2 seconds; measure it.
- Dates that matter: today 2026-11-15, Black Friday 2026-11-27, Cyber Monday 2026-11-30.

## Module docs

- [Data and retrieval](data.md), [shopping agent](agent.md), [monitoring](monitoring.md),
  [iOS capture](ios-capture.md) (phone side, for reference), [how the crew works](orchestration.md).
