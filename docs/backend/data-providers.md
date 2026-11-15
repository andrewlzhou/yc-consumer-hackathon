# Data providers

- Real data first, but no paid APIs (Ruhaan, 2026-11-15). Current prices come from SerpApi, real history from Wayback snapshots.
- No keys exist yet. Each function returns `{ status: "no_key" }` without its env var, so none of this has run live.
- "Fixture-tested" means the parser runs against a response written by hand from the provider's docs. It does not prove the live API matches.

## SerpApi: current prices and Google's price history

- Returns: current offers across retailers (price, "was" price, link) from `google_shopping`, plus per-store price history from `google_product` (`price_insights`).
- Env var: `SERPAPI_API_KEY`.
- Call: `internal.data.sources.serpapi.refreshCurrentPrices({ productId })`. It writes observations with source `api` and providers `serpapi-google-shopping`, `serpapi-google-product`, `serpapi-google-price-history`.
- Cost: one search finds the Google product id (once per product), one more reads the product page. Billed per search on the plan.
- Terms: results are Google Shopping listings. The parser drops used, refurbished, accessories, and other variants.
- Verified: fixture-tested only. Details live in `convex/data/sources/serpapi.ts`.

## Wayback Machine snapshots: real history

- Returns: archived retailer product pages, read for the price shown on each snapshot date.
- Free, no key. Being built by the data thread: provider `wayback`, source `scrape`.
- Status: in progress. Not documented here until it exists.

## Best Buy: optional live price only

- Returns: current `regularPrice`, `salePrice`, `onSale`, `sku`, `name`, `url` for matching products.
- Env var: `BESTBUY_API_KEY` (free key, optional). Without it the app simply skips Best Buy.
- Call: `internal.data.sources.bestbuy.getLivePrice({ query?, sku? })` returns `{ status, offers, latencyMs }`.
  - A query is a keyword search joined with AND; a sku uses the single-product endpoint.
- It never writes observations. Best Buy's terms forbid caching content except temporarily, and product links expire after seven days.
  - Show the price to the user now; do not store it as history. Our own scans can still record what a shopper saw.
- Limits: the docs mention query-per-second limits, so avoid bursts.
- Verified from the docs (https://bestbuyapis.github.io/api-documentation/): endpoint shapes, `show=` field filter, collection and single-product response shapes, the caching rule.
- Not verified: any live response, exact rate limits. Fixture-tested only.

## Keepa: not used (paid, no key)

- Code exists in `convex/data/sources/keepa.ts` (`ingestHistory`, `searchAsins`) and is fixture-tested, but it is not used: paid, no key. Env var would be `KEEPA_API_KEY`.
- It would store one sample per UTC day (price at 17:00 UTC) for Amazon, falling back to the buy box series.
- Cost if ever enabled: 1 token per ASIN, at least 5 with the `offers` parameter the buy box needs, 10 per search.
- Doc facts checked 2026-11-15 at https://keepa.com/api-docs/product-object.html: csv index 0 Amazon, 18 buy box with shipping, time offset 21564000 minutes, prices in cents, `-1` = no offer.
- Not verified live.
