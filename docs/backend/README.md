# Backend (Convex)

- Convex is a hosted backend: a database plus server functions, written in TypeScript in `convex/`.
- Status: schema and the phone contract exist; data, agent, and monitoring work is in progress on branch
  `ruhaan_backend`. No cloud deployment exists yet, so development uses a local backend.

## Guides

- [Product context](product.md) — what the backend must do and the hard constraints.
- [Phone contract](contract.md) — what the phone sends and what it gets back.
- [Data and retrieval](data.md), [shopping agent](agent.md), [monitoring](monitoring.md).
- [iOS capture](ios-capture.md) — how the phone side works, for reference.
- [How the crew works](orchestration.md) — branch, pushing, file ownership, models.

## Run it locally (no Convex account)

- Install packages: `npm install` (Node 20 or newer; Node 22+ for the AI-files step).
- Start a local backend: `env -u CONVEX_DEPLOY_KEY -u CONVEX_DEPLOYMENT CONVEX_AGENT_MODE=anonymous npx convex dev`.
  Unsetting the deploy key matters: when `CONVEX_DEPLOY_KEY` is set, Convex ignores anonymous mode and pushes to the
  shared cloud deployment. The command downloads the backend binary, runs it on
  `127.0.0.1:3210`, and writes `.env.local`. Git ignores that file.
- With a Convex account, `npm run dev` creates a cloud dev project instead.

## Checks

- `npm run typecheck` — TypeScript over `convex/`.
- `npm test` — vitest with `convex-test`, an in-memory Convex backend. Tests live next to code as `*.test.ts`.
- `python3 scripts/check_docs.py` — doc lengths.

## Files

- `convex/schema.ts` — tables. Each workstream adds its own tables in its own block.
- `convex/lib/contract.ts` — the phone contract as types and validators.
- `convex/_generated/` — written by Convex tools. Commit it; don't edit it by hand.
- `convex/_generated/ai/guidelines.md` — Convex's rules for writing Convex code. Agents read this first.
- `.agents/skills/` and `.claude/skills/` — Convex's task guides for coding agents. `skills-lock.json` pins them.

## Updating the AI files

- Run `npx convex ai-files install`. The skills step needs Node 22 or newer.
- It also adds a Convex block to `CLAUDE.md`. Delete that copy: `CLAUDE.md` already loads `AGENTS.md`.
