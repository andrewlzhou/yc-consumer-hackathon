# More consumer stores

- Ruhaan's scope: survey broadly, support only a few stores with real historical data; Nike and Adidas were examples.
- Free sources only. SerpApi's 250 searches/month are shared; never put source calls in tests or on the live analysis path.
- Measured feasibility and exact URLs: [survey](data-stores-survey.md). Implementation: `convex/data/sources/stores/`.
- Known store slugs added separately: `nike`, `ae`, `lululemon`, `apple`. All existing retailers remain accepted.

## Page reader

- `readStructured(html, url?)`: schema.org Product/ProductGroup JSON-LD, then product/OpenGraph price meta tags.
- Arrays, graphs, variants, USD, availability, and explicit list/strikethrough specifications are handled.
- Conflicting variant prices are rejected unless the URL singles out a variant; no cheapest-color guess.
- Nike's selected style-color supplies `currentPrice` and `initialPrice`; employee prices are ignored.
- American Eagle's size rows supply `salePrice` and `listPrice`.
- Existing Amazon/Walmart/Target/Best Buy parsers stay intact; the generic reader serves other stores.
- Real-excerpt fixtures include Nike, AE, lululemon, Apple and Home Depot; blocked archive stubs yield no price.

## Background URL resolution

- Internal action: `data/sources/stores/resolve:resolveUrl`, args `{url, title?, retailer?}`.
- Returns `{productId?, title?, retailer?, currentPrice?, originalPrice?, matched?, via?, observedAt?}`, or null.
- It reads a supported product page, tries up to three recent archived copies if needed, then matches or creates a provisional product.
- Supported hosts: the four stores above plus Amazon, Walmart, Target and Best Buy. Unsupported hosts/paths return null.
- The host is taken from the URL, not a caller's retailer hint. Userinfo, custom ports and arbitrary subdomains are refused.
- Store redirects are not followed into arbitrary sites. Failed pages are not catalog evidence.
- Variant query fields survive canonicalization; unresolved color/size/SKU selections never fall back to another offer.
- Old snapshot prices are stored at the snapshot timestamp, never passed back as today's price (three-day freshness bound).
- Plain `parseUrl(url)` in `stores/url.ts` uses no network and returns the store slug, product code and optional title hint.
- The agent calls resolution only in its scheduled background job. No page fetch was added to live `/analyze`.

## Ingestion and demo

- `data/sources/wayback:ingest` uses the same reader and writes through `recordBatch`: source `scrape`, provider `wayback`.
- Optional `prefix:true` includes tracking-query copies, but only for the same product path. Writes remain daily/idempotent.
- Google offers/history use the existing SerpApi adapter and its existing provenance fields; no parallel ingestion system.
- Demo definitions: AE Baggy Jean (Black 33×32), lululemon Align 25-inch, Nike Zenvy leggings;
  load each with `npx convex run data/demo:ingest '{"key":"ae-baggy-jean"}'` (replace the key for the other two).
- The leggings are genuine cross-brand alternatives, not interchangeable models. AE's older archived color is not merged into its Google product.
- AE is eligible for the existing daily SerpApi refresh. The two leggings products skip SerpApi until an exact matching Google product is verified.
- Apple adds archive points to the existing AirPods Pro 3 demo rather than introducing another product.
- Deployment ingestion and final row counts are pending; do not present these additions as live yet.
