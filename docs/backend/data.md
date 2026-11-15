# Data and retrieval

- Owned by the data thread. Built from Ruhaan's spec 03 (2026-11-15); this page tracks what actually exists.
- Status: retrieval, seed and real-data ingestion work; the real demo set is in [data-demo.md](data-demo.md).

## Tables

- `retailers`: slug (`target`, `walmart`, `bestbuy`, `amazon`) and display name.
- `products`: the catalog. Title, brand, model, category, specs, aliases, and `searchText` for full-text search.
  - `familyKey` groups variants of one model; `variant` holds what changes price (storage, size, pack).
  - `isSample` marks seeded products; `provisional` marks products created from an unmatched scan.
- `productEmbeddings`: one 1536-float vector per product (OpenAI text-embedding-3-small) for hybrid search.
- `priceObservations`: one observed price per row.
  - `observedAt` is when the price was true, separate from `_creationTime`, so history can be backfilled.
  - `originalPrice` is the retailer's claimed "was" price, kept apart from `price` for discount checks.
  - `source` is `scan`, `api`, `scrape`, or `seed`. Seed data must be labeled and never fires notifications.
  - Out of stock or hidden price: `inStock: false` and no `price`. Missing, never zero.
- `saleEvents`: the sale calendar. National events and retailer sales, with `dateConfidence` confirmed or estimated.
- `priceDigests`: a short text summary plus counts per product, so the agent reads a paragraph, not raw points.

## Providers

- Real-data sources (SerpApi, Wayback, Best Buy; Keepa unused), their env vars, costs, and what is verified: [data providers](data-providers.md).
- Generic store parsing, URL resolution and the consumer-store survey: [more stores](data-stores.md).

## Rules

- Read history in bounded windows only, never unbounded.
- Exact math (averages, percentiles, lows) lives in code; the agent calls it.
