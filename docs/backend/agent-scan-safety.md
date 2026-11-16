# Shopping agent: phone scan safety

- Rules for what `/analyze` trusts from a phone, added after real iPhone 14 tests (CON-10, CON-11, 2026-11-15).
- Code: `convex/agent/screenText.ts`, `analyze.ts`, `urls.ts`, `evidence.ts`, `facts.ts`. Tests: `agent/phoneScan.test.ts`.

## Screen text

- Text is NFKC-normalized and stripped of format characters (zero-width spaces) before any check.
- Dropped: personal shapes (greeting plus punctuation or emoji, @, phone numbers, state+ZIP, street address, apartment,
  "Deliver to", `Name: message` banners, chat phrases) and store chrome ("Best Buy App", "Amazon Prime", "Target Circle").
- Trusted only with a product signal: a model code (XM5, 128GB), a number of 2+ digits, or a product word (jeans, mug).
  "Welcome, Ruhaan", "Ruhaan Singh" or "Mom" never qualify; "Hello Kitty Plush Toy 12 inch" does.
- Untrusted text (signal-less titles, OCR lines minus personal lines, URL slugs) may find a clear catalog match in
  code, but never creates a provisional product, reaches an embedding, model or SerpApi call, or is stored in `agentScans`.
- After an OCR-only match, the analysis uses the catalog title, so screen text never reaches the model.
- No trusted title and no link: INVESTIGATE "We couldn't recognize a product name...", with no product, scan price,
  stored title, or paid call. The scan row keeps only retailer, price, verdict and latency.

## Links

- Amazon `/dp/`, `/gp/product/` and `/gp/aw/d/` links match the catalog by exact ASIN
  (`data/catalog:productByAsin`, index `by_identifiers_asin`). No page fetch and no background resolution then.
  An unknown ASIN goes to the stores resolver in the background, which may fetch the amazon.com page and Wayback.
- `a.co` and `amzn.to` short links are expanded only in the background: at most three redirects, each read without its
  body, and only to a.co, amzn.to, amzn.com or amazon.com. Any other host, a port or user info, or a page without an
  ASIN fails the link. Expansion never fetches amazon.com; the final ASIN is parsed from the URL.
- AE and Nike codes name one color (case-insensitive). A match by title, slug, background title fallback, or an
  earlier cached link is dropped unless the product's `model` is that code or its title carries it, so color 914
  never shows Black 33×32 history. The tracked Black product's code is unknown (its model is a Google id), so no AE
  link matches it yet. A blocked page creates "<title> <code>" from a trusted title, kept apart from other colors.
- A link that failed to resolve says so ("We couldn't identify this product from its link...") instead of blaming OCR.
- Thin history says what we have: "We have only 1 price for this exact item (latest $34.96 on 2026-01-30)...".

## Price relations

- `key_facts` gives `priceVsLowest` (`below_lowest_recorded`, `equals_lowest_recorded`,
  `within_3_percent_above_lowest`, `more_than_3_percent_above_lowest`), `currentVsLowestPercent` and
  `currentPriceSource` (`scan` or `stored`). The old `withinThreePercentOfLowest` was true for any price below the low.
- `relationIssues` checks each clause: "within N% of", "N% below/above" (either base), "$N below/above", "matches"
  (1%), and "is a new/record low" against key_facts. Subjects are the clause's first or nearest earlier price, a later
  "at $A", or today's price; "the low" without a price is key_facts' lowest. Negated claims are skipped.
- A false relation is a grounding issue: one repair, then the deterministic analyst. Cached analyses failing it are rerun.
- The deterministic BUY_NOW reason states the exact relation (below, matches, N% above, or cheapest N% of prices).

## Measured (local anonymous backend, fake model, 2026-11-15)

- AE color-914 link: 0.10 s pending card; after background resolution 0.05 s INVESTIGATE (real Wayback $34.96 page).
- Amazon /dp/B09XS7JWHH: 0.16 s live card for the XM5. OCR banner and "Best Buy App": 0.02-0.04 s INVESTIGATE.
- Budget: the embedding gets at most 1.5 s, the match pick what is left; a failed embedding falls back to text match.
  Test with 2.5 s embedding and 2.4 s pick returns under 4.3 s (was 4.97 s in review).
- Not measured: real OpenAI latency on the shared deployment, and a real a.co link (none was available).
