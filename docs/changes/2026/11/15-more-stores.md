# 2026-11-15 — More consumer stores

- Author: Capy (YCCO-8), requested by Ruhaan Singh through Captain Ruhaan.
- Instructions: survey big consumer stores broadly, then support only a few with real history; free sources only, shared SerpApi budget, no store-page fetch on the live analysis path. Nike and Adidas were examples, not required stores.
- Changed: registered Nike, American Eagle, lululemon and Apple as known retailers, including Google's merchant aliases. This small shared-file change is separate from the stores parser and demo changes.
- Checks: local anonymous Convex codegen, typecheck and full suite passed before this commit (160 tests, two live tests skipped). New store parsing work is still being finalized separately.
- Next: ship the generic page reader and background URL resolver, then ingest and verify the real-data demo from a clean branch tip.
