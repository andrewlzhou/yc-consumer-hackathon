# Current decisions

- Updated: 2026-11-15. This file holds today's choices, not a running diary. When a topic grows large, move it to its own `decisions-<topic>.md` and link it here.

## From the owners

- 2026-11-15: the product is an AI shopping assistant that says whether to buy now or wait; see the [README](../../README.md).
- Work is split into three workstreams that each get improved over time: backend, surfacing, and UI/UX.

## Initial setup choices

- Convex is the backend (database and server functions). Chosen 2026-11-15. See [backend](../backend/README.md).
- Commit `convex/_generated/`, `.agents/skills/`, `.claude/skills/`, and `skills-lock.json`, so every clone has the same Convex code and agent guides.

## Open questions

- Where historical price data comes from, and which retailers are covered first.
- Client platform: iPhone app, Safari extension, or both, and which entry point comes first.
- How competing products are found and matched for comparison.
