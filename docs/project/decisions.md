# Current decisions

- Updated: 2026-11-15. This file holds today's choices, not a running diary. When a topic grows large, move it to its own `decisions-<topic>.md` and link it here.

## From the owners

- 2026-11-15: the product is an AI shopping assistant that says whether to buy now or wait; see the [README](../../README.md).
- Work is split into three workstreams that each get improved over time: backend, surfacing, and UI/UX.
- 2026-11-15 (Ruhaan): the client is an iOS 26 app in SwiftUI. Back Tap running a Shortcut is the first trigger;
  Control Center, Action Button, or share menu can replace it later. See [iOS capture](../backend/ios-capture.md).
- 2026-11-15 (Ruhaan): the screenshot never leaves the phone and is never stored; only extracted fields are sent.
- 2026-11-15 (Ruhaan): the backend is an LLM agent that reasons over retrieved evidence, not a rules engine.
  Exact math, storage, scheduling, and caching stay in code. See [product context](../backend/product.md).
- 2026-11-15 (Ruhaan): seeded or simulated data is always labeled as sample data and never fires real notifications.
- 2026-11-15 (Ruhaan/Captain, CON-10): screen text (title, OCR lines) only runs local catalog matching; it never creates
  a product, is stored, or reaches a paid call. New products come only from product links. See [scan safety](../backend/agent-scan-safety.md).
- 2026-11-15 (Ruhaan): backend work lands on branch `ruhaan_backend`. See [orchestration](../backend/orchestration.md).

## Initial setup choices

- Convex is the backend (database and server functions). Chosen 2026-11-15. See [backend](../backend/README.md).
- Commit `convex/_generated/`, `.agents/skills/`, `.claude/skills/`, and `skills-lock.json`, so every clone has the same Convex code and agent guides.
- The phone contract lives in `convex/lib/contract.ts`; see [contract](../backend/contract.md).
- Tests use vitest with convex-test (in-memory). Local development uses an anonymous local Convex backend until a cloud
  deployment exists.

- 2026-11-15: the agent is a hand-rolled tool loop over the OpenAI Responses API (fetch, no SDK), not
  `@convex-dev/agent`: analyses are one-shot, with no conversation history to persist. See [agent](../backend/agent.md).
- 2026-11-15 (Ruhaan): keep the phone side light. Live path = cached analysis or one fast small-model call;
  the detailed report is a separate on-demand endpoint.
- 2026-11-15: full reports start alongside the live card and use one prefetched model pass; exact report sections
  and a chart are available before the full narrative. Product-page fetching stays off the live path.

## Open questions

- Which price data sources we can use this weekend, and which retailers work live versus seeded.
- How competing products are found and matched for comparison.
- Push delivery: APNs from Convex, a relay, or local notifications as the demo fallback.
- What role Revyl (required by the hackathon) should play; it likely can't test Back Tap. Ask the organizers.
