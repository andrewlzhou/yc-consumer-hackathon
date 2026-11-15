# 2026-11-15 — Convex setup

- Author: Claude (Opus 5.5), requested by Andrew.
- Instructions: set up Convex per its official agent setup guide; leave `npx convex dev` (login and cloud project) to a person. Saved as a decision and in [backend](../../../backend/README.md).
- Changed: added `package.json` with `convex` 1.48.0 and a `dev` script, an empty `convex/schema.ts`, Convex's AI guidelines, and its agent skills. Convex added a block to `AGENTS.md`.
- Changed: removed the duplicate Convex block Convex wrote into `CLAUDE.md`, since `CLAUDE.md` imports `AGENTS.md`.
- Changed: installed the Convex plugin for Claude Code at user scope on this machine.
- Checks: `convex/_generated/ai/guidelines.md` and `.agents/skills/` exist; `claude plugin list` shows the plugin enabled; `tsc` type-checked `convex/schema.ts`; `python3 scripts/check_docs.py` passed.
- Checks: the skills step failed on this machine's Node 20; it worked on a temporary Node 22.
- Next: a person runs `npm run dev` to log in and create the Convex dev project. Not yet run, so the rest of `convex/_generated/` doesn't exist yet.
