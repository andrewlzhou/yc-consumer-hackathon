# Data providers

- Real data first: current prices, Amazon history, and Best Buy live prices come from these three providers.
- No keys exist yet. Every function returns `{ status: "no_key" }` without its env var, so nothing here has run live.
- "Fixture-tested" means the parser runs against a response written by hand from the provider's docs. It does not prove the live API matches.

## SerpApi (Google Shopping)

- Returns: current offers across retailers (price, "was" price, link) for one product title.
- Env var: `SERPAPI_API_KEY`.
- Call: `internal.data.sources.serpapi.refreshCurrentPrices({ productId })`. It writes observations (source `api`, provider `serpapi-google-shopping`).
- Cost and limits: one search per call, billed per search on the plan; see `convex/data/sources/serpapi.ts`.
- Terms: results are Google Shopping listings; keep titles filtered to the exact product (the parser drops used, refurbished, accessories, other variants).
- Verified: fixture-tested only.
- SerpApi product/insights: in progress (data thread).

## Keepa (Amazon price history)

- Returns: the Amazon price history as change points (price in cents, `-1` = no offer, Keepa time = minutes since 2011-01-01).
- We store one sample per UTC day (price at 17:00 UTC), in dollars. Out-of-stock days store `inStock: false` and no price.
- Env var: `KEEPA_API_KEY`.
- Call: `internal.data.sources.keepa.ingestHistory({ productId, days? })` (default 365; needs `identifiers.asin`). Writes through `recordBatch`, retailer `amazon`, source `api`, provider `keepa-amazon`.
- Returns `{ status, recorded, series, tokensLeft, latencyMs }`. Re-running is safe: days already stored for the provider are skipped.
- Buy box fallback: if Amazon never had an offer in the window, we use the New buy box series (price plus shipping), provider `keepa-buybox`.
  - The buy box needs the `offers` parameter, so the action asks for it only after a cheap first request finds no Amazon price.
- Find an ASIN: `internal.data.sources.keepa.searchAsins({ term })` returns the top 5 `{ asin, title }`.
- Cost: a product request is 1 token per ASIN; with `offers` it is at least 5 tokens. A search is 10 tokens. `history`, `days`, `stats` are free.
- Limits: the plan has a tokens-per-minute bucket (20 per minute on the smallest plan). Out of tokens returns HTTP 429, reported as `rate_limited`.
- Terms: paid API for commercial use; it is plan-based, so keep calls to the demo products and let the 17:00 sampling keep rows small.
- Verified from docs (2026-11-15): csv indices (0 Amazon, 1 New, 18 buy box with shipping), time offset 21564000, cents, `-1`, `days`/`history` parameters, token costs, status codes.
- Not verified: any live response, how Keepa trims history at the start of the `days` window, and whether prices include tax or coupons.

## Best Buy (live price only)

- Returns: current `regularPrice`, `salePrice`, `onSale`, `sku`, `name`, `url` for matching products.
- Env var: `BESTBUY_API_KEY`.
- Call: `internal.data.sources.bestbuy.getLivePrice({ query?, sku? })` returns `{ status, offers, latencyMs }`. A query is a keyword search joined with AND; a sku uses the single-product endpoint.
- It never writes observations. Best Buy's terms forbid caching content except temporarily, and product links expire after seven days.
  - Show the price to the user now; do not store it as history. Our own scans can still record what a shopper saw.
- Limits: keys are free; the docs mention query-per-second limits, so avoid bursts.
- Verified from docs: endpoint shapes, `show=` field filter, collection and single-product response shapes, the caching rule.
- Not verified: any live response, the exact rate limits.
