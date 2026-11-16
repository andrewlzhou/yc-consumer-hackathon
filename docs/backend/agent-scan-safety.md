# Shopping agent: phone scan safety

- Rules for what `/analyze` trusts from a phone, added after real iPhone 14 tests (CON-10, CON-11, 2026-11-15).
- Code: `convex/agent/screenText.ts`, `analyze.ts`, `urls.ts`, `evidence.ts`, `facts.ts`. Tests: `agent/phoneScan.test.ts`.

## Screen text

- Only a usable phone `title` is trusted. It is dropped when it looks personal (greeting, @, phone number, street
  address, apartment, "Deliver to", a `Name: message` banner, chat phrases) or is only store chrome ("Best Buy App").
- `ocrLines` lose personal-looking lines first. OCR text and URL slugs may find a clear catalog match in code, but
  never create a provisional product, reach an embedding or model call, or get stored in `agentScans`.
- After an OCR-only match, the analysis uses the catalog title, so screen text never reaches the model.
- No usable title and no link: INVESTIGATE "We couldn't find a product name on the screen", with no product, scan price,
  stored title, or paid call. The scan row keeps only retailer, price, verdict and latency.

## Links

- Amazon `/dp/`, `/gp/product/` and `/gp/aw/d/` links match the catalog by exact ASIN
  (`data/catalog:productByAsin`, index `by_identifiers_asin`). No page fetch and no background resolution then.
- `a.co` and `amzn.to` short links are expanded only in the background: at most three redirects, each read without its
  body, and only to a.co, amzn.to, amzn.com or amazon.com. Any other host, a port or user info, or a page without an
  ASIN fails the link. Amazon hosts are never fetched; their ASIN is parsed from the URL.
- AE and Nike codes name one color. A title or slug match to a product whose `model` is a different code is dropped,
  so color 914's link never shows the tracked Black 33×32 history. The resolver gives that color its own product.
- A link that failed to resolve says so ("We couldn't identify this product from its link...") instead of blaming OCR.
- Thin history says what we have: "We have only 1 price for this exact item (latest $34.96 on 2026-01-30)...".

## Price relations

- `key_facts` gives `priceVsLowest` (`below_lowest_recorded`, `equals_lowest_recorded`,
  `within_3_percent_above_lowest`, `more_than_3_percent_above_lowest`), `currentVsLowestPercent` and
  `currentPriceSource` (`scan` or `stored`). The old `withinThreePercentOfLowest` was true for any price below the low.
- `relationIssues` checks each clause: "$A within N% of $B", "$A N% below/above $B" (either base), "$A matches $B"
  (1%) and "new low" against key_facts. A false relation is a grounding issue: one repair, then the deterministic analyst.
- The deterministic BUY_NOW reason states the exact relation (below, matches, N% above, or cheapest N% of prices).

## Measured (local anonymous backend, fake model, 2026-11-15)

- AE color-914 link: 0.10 s pending card; after background resolution 0.05 s INVESTIGATE (real Wayback $34.96 page).
- Amazon /dp/B09XS7JWHH: 0.16 s live card for the XM5. OCR banner and "Best Buy App": 0.02-0.04 s INVESTIGATE.
- Not measured: real OpenAI latency on the shared deployment, and a real a.co link (none was available).
