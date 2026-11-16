# 2026-11-15 — More consumer stores

- Author: Capy (YCCO-8), requested by Ruhaan Singh through Captain Ruhaan.
- Instructions: survey big consumer stores broadly, then support only a few with real history; free sources only, shared SerpApi budget, no store-page fetch on the live analysis path. Nike and Adidas were examples, not required stores.
- Changed: registered four stores separately (7ab91ff); added the generic JSON-LD/meta reader, Nike/AE list-price extras, strict product URLs, background resolver and tracking-query archive ingestion. Measured [18 stores](../../../backend/data-stores-survey.md); support and limits are in [store data](../../../backend/data-stores.md).
- Changed: connected exactly three store demo products in a separate shared-demo-file commit; only AE joins the daily Google refresh, so the other two do not waste the shared search allowance. Apple extends the existing AirPods product.
- Changed: retained variant query fields through URL resolution and refused unidentifiable selections after YCCO-4 independently flagged this identity risk.
- Changed: tracking-query archive ingestion rejects variant query changes; removed one color-specific Align point and reingested canonical copies. Unequal AggregateOffer ranges are not exact prices.
- Changed: restricted Nike/AE URLs and Nike's fallback to the verified US/USD layouts.
- Checks: clean-tip shared-dev deploys and real ingestion; Nike/Apple/lululemon/Walmart URL matches; cross-brand comparables; real AE live/full eval both grounded WAIT (1.08s/8.51s). Full suite 174 passed, two live monitoring tests skipped; typecheck and docs pass. Evidence: [live stores](../../../backend/data-stores-live.md).
- Limits: Align's current price and exact Google refresh are unverified; its archive evidence is stale. No claim that the AE list price was never charged. Claude quota exhausted; continued on OpenAI as requested.
