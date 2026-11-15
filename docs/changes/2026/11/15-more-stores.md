# 2026-11-15 — More consumer stores

- Author: Capy (YCCO-8), requested by Ruhaan Singh through Captain Ruhaan.
- Instructions: survey big consumer stores broadly, then support only a few with real history; free sources only, shared SerpApi budget, no store-page fetch on the live analysis path. Nike and Adidas were examples, not required stores.
- Changed: registered four stores separately (7ab91ff); added the generic JSON-LD/meta reader, Nike/AE list-price extras, strict product URLs, background resolver and tracking-query archive ingestion. Measured [18 stores](../../../backend/data-stores-survey.md); support and limits are in [store data](../../../backend/data-stores.md).
- Checks: local anonymous Convex codegen; typecheck; focused real-excerpt parser/resolver tests. Full suite verification is repeated before pushing.
- Next: connect the three demo additions in a separate commit, deploy a clean branch tip, ingest and verify real data. Claude quota exhausted; continued on OpenAI as requested.
