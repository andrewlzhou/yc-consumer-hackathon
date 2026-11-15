# Shopping agent (plan)

- Condensed from Ruhaan's spec 02 (2026-11-15). Owned by the shopping-agent thread, which replaces this with what it builds.
- Status: not built yet.

## Goal

- Take a scanned extract and return a grounded verdict and reason, plus a richer stored analysis record.

## Suggested design

- An LLM tool-use loop in a Convex action. Tools retrieve and calculate; the model decides and explains.
- Tools come from [data and retrieval](data.md): catalog search, bounded price history, exact stats,
  promo patterns, sale calendar, digests, and recording the scanned price.
- Competitor specs and prices only from retrieved or verified sources. Never invent a product.
- Output follows a schema and is validated before returning. Thin evidence gives INVESTIGATE with a clear reason.
- Prompt with the four verdict definitions and misleading-discount signals: a "was" price that rarely existed,
  a hike just before a sale, a repeating cycle where the "sale" is the normal price, big claimed savings with small real ones.

## Speed

- The user waits in a store app; aim for about 2 seconds and measure.
- Starting idea, to be tested: a live path that returns a cached analysis or runs a short pass, and a background path
  that runs the full agent when a product is first seen, when analysis is stale, or on a schedule.
- Unknown product: return INVESTIGATE fast and queue the full analysis.

## Identifying the product

- Normalize the title, search the catalog, let the model pick among close candidates or say none.
- Storage, size, and pack size change price; color usually doesn't. Variants share a `familyKey` in the catalog.
- No match: create a provisional product and treat it as thin evidence.

## Endpoint basics

- HTTP actions have no automatic validation or auth: check an API key, validate input by hand, call internal functions,
  always return well-formed JSON. Every scan records the observed price.

## Evaluation

- `eval/cases.json` holds the seeded products plus adversarial cases and what a sensible shopper should be told.
- Judge on whether the conclusion is sensible and grounded, not exact wording.
