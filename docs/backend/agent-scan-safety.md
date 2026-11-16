# Shopping agent: phone scan safety

- Rules for what `/analyze` trusts from a phone, added after real iPhone 14 tests (CON-10, CON-11, 2026-11-15).
- Code: `analyze.ts`, `urls.ts`, `evidence.ts`, `facts.ts`. Tests: `agent/phoneScan.test.ts`.

## Screen text (Captain decision, 2026-11-15)

- The phone's `title` and `ocrLines` can be a notification, a one-time code, a payment or an address, and no list of
  patterns proves arbitrary text safe. So screen text runs local, deterministic catalog matching only, each piece
  needing a clear `matchProduct` match that names the product's brand or full model ("AirPods" or "Pro 3" alone
  is not enough; brandless link-created products keep the bar alone). The phone's title names one product, so its match wins. Otherwise each OCR
  line, the joined lines and the URL slug must all match the same product; two different products (an ad, "customers
  also bought") give INVESTIGATE "This screen shows more than one product. Share its product page link...".
- It never creates a product, is never stored (`agentScans` keeps no title), and never reaches an embedding, model
  or SerpApi call. After a match the model sees the catalog title, never the screen text.
- No clear match: INVESTIGATE "We don't recognize this product yet. Share its product page link and we'll look it up."
- Tradeoff: an unknown product on a screenshot now asks for its link instead of being discovered automatically.
  Close-but-unclear titles no longer get a model pick. New products come only from supported product links whose
  store page names them (provider-verified identity).
- Matching fix: a token and its OCR readings ("afl0l", "af101") count once in the score, so OCR fixes don't dilute it.

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
  link matches it yet. A page title without a product creates "<title> <code>", kept apart from other colors. A link cached to
  another color is released and resolved again.
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
- Budget: the live path no longer embeds or picks for screen text, so identify is local reads only.
- Not measured: real OpenAI latency on the shared deployment, and a real a.co link (none was available).
