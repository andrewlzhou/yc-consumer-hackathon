# 2026-11-15: phone scan safety (CON-10, CON-11)

- Author: Capy thread YCCO-12 for Captain Ruhaan (YCCO-2), from real iPhone 14 tests (YCCO-10) and the iOS review (YCCO-11).
- Instructions: work on isolated branch `ruhaan_backend_phonefix`, PR to `ruhaan_backend`, no merge, no shared deploy,
  no ios/** edits, no paid calls in tests. Task-specific; no new lasting rule. Behavior is in [scan safety](../../../backend/agent-scan-safety.md).
- Changed: false price relations ("$179 within 3% of $198") are now grounding issues, `key_facts` labels the relation
  exactly, and the fallback reason states it. Amazon /dp/ links match by ASIN; a.co/amzn.to expand safely in the
  background. AE/Nike color codes keep variants apart; failed links and thin history explain themselves.
  OCR-only, personal and store-chrome text ("Best Buy App") never creates products, stores titles, or makes paid calls.
- Changed: live path has a 4 s budget. Fake provider reads the 365-day stats, as the prompt intends.
- Contract: no type change; `ocrLines` behavior is narrower (contract.md updated). New products index `by_identifiers_asin`.
- Checks: `npm run typecheck`, `npx vitest run` (197: 195 passed, 2 live skipped), `python3 scripts/check_docs.py`,
  local anonymous `npx convex dev` push and HTTP probes (latencies in scan-safety doc). No shared deployment.
- Next: deploy after review; verify on the shared deployment with the real model and the phone. A real a.co link and
  the XM4C (M4 2nd Gen) match are unverified. Phone side must still re-POST a pending link (M6).
