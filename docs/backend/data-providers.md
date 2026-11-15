# Data providers

- Real data first. Paid APIs are allowed (Andrew, 2026-11-15, replacing the earlier "no paid APIs" rule): SerpApi for
  Google Shopping prices and per-store history, Keepa for Amazon history. Keep SerpApi swappable: the Google v. SerpApi
  lawsuit may be refiled by 2026-11-30, so other code should not depend on SerpApi's response shapes.
- Keys pending: Andrew will set `SERPAPI_API_KEY` (paid plan) and `KEEPA_API_KEY` on the shared dev deployment.

## Layered plan (Andrew, 2026-11-15; not all built yet)

- Identify the product: page JSON-LD read on the phone, IDs in the product URL, then a UPC lookup.
- Current prices: SerpApi `google_product`, plus the Best Buy API.
- History: Google's per-store history via SerpApi, Keepa for Amazon ASINs, our own stored observations; Wayback only
  as background.
- Stores with no history anywhere (Costco, eBay, small brand stores) return INVESTIGATE.
- Without its env var each function returns `{ status: "no_key" }`. The shared deployment has `SERPAPI_API_KEY` and `OPENAI_API_KEY`.
- "Fixture-tested" means the parser runs against a saved response. The demo set is in [data-demo.md](data-demo.md).

## SerpApi: current prices and Google's price history

- Returns: current offers across retailers (price, "was" price, link) from `google_shopping`, plus per-store price history from `google_product` (`price_insights`).
- Env var: `SERPAPI_API_KEY`.
- Call: `internal.data.sources.serpapi.refreshCurrentPrices({ productId })`. It writes observations with source `api` and providers `serpapi-google-shopping`, `serpapi-google-product`, `serpapi-google-price-history`.
- Cost: one search finds the Google product id (once per product), one more reads the product page. Free plan: 250 searches/month.
- History: Google lists a store's price only on days it changed. We expand each change to one point per day until the next
  change, so medians and "share of days at the was-price" are time-weighted. Marketplace sellers ("Walmart - X") are skipped.
- Offer guards: first-party retailers only; no used, refurbished, accessories, bundles or kits; no other model with the
  same shape (1000xm5 vs 1000xm6); no earbuds for headphones; price within 40-200% of MSRP. A Google product id whose
  page returns nothing is forgotten, so the next refresh searches again.
- Verified live 2026-11-15: `google_product` returns about a year of per-store history (XM5: 28 Best Buy and 21 Target
  price changes since 2025-11-14). Real response saved as `fixtures/serpapi-product-xm5.json` and tested.

## Wayback Machine snapshots: real history

- Returns: archived retailer product pages, read for the price shown on each snapshot date.
- Free, no key: `internal.data.sources.wayback.ingest({ productId, retailer, url })`, provider `wayback`, source `scrape`,
  observedAt = snapshot time, url = the snapshot (evidence). One request at a time with a 1.2 s pause.
- Yield (2026-11-15): Best Buy and Walmart pages parse well but have few captures (1-29 a year). Archived Amazon pages show
  "No featured offers" (no buy box for the crawler), so they give no price. Newer Target pages render prices client-side.
- Terms: archive.org is free for research use; we fetch slowly, keep evidence links, and never hit retailer sites directly.

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

## Keepa: planned, key pending

- Code exists in `convex/data/sources/keepa.ts` (`ingestHistory`, `searchAsins`) and is fixture-tested. Not used until
  Andrew sets `KEEPA_API_KEY`.
- It would store one sample per UTC day (price at 17:00 UTC) for Amazon, falling back to the buy box series.
- Cost if ever enabled: 1 token per ASIN, at least 5 with the `offers` parameter the buy box needs, 10 per search.
- Doc facts checked 2026-11-15 at https://keepa.com/api-docs/product-object.html: csv index 0 Amazon, 18 buy box with shipping, time offset 21564000 minutes, prices in cents, `-1` = no offer.
- Not verified live.
