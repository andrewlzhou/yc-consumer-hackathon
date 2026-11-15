# 2026-11-15 — More consumer stores

- Author: Capy (YCCO-8), requested by Ruhaan Singh through Captain Ruhaan.
- Instructions: survey big consumer stores broadly, then support only a few with real history; free sources only, shared SerpApi budget, no store-page fetch on the live analysis path. Nike and Adidas were examples, not required stores.
- Changed: registered four stores separately (7ab91ff); added the generic JSON-LD/meta reader, Nike/AE list-price extras, strict product URLs, background resolver and tracking-query archive ingestion. Measured [18 stores](../../../backend/data-stores-survey.md); support and limits are in [store data](../../../backend/data-stores.md).
- Changed: connected exactly three store demo products in a separate shared-demo-file commit; only AE joins the daily Google refresh, so the other two do not waste the shared search allowance. Apple extends the existing AirPods product.
- Changed: retained variant query fields through URL resolution and refused unidentifiable selections after YCCO-4 independently flagged this identity risk.
- Changed: tracking-query archive ingestion also rejects color/SKU/size query changes; one same-price color-specific Align point from the first backfill will be removed before final verification.
- Checks: local anonymous Convex codegen; typecheck; full suite 166 passed with two live tests skipped; real AE response ingested in convex-test and proves its list price was rarely, but sometimes, charged.
- Next: deploy a clean branch tip, ingest and verify real data. Claude quota exhausted; continued on OpenAI as requested.
