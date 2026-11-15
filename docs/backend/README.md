# Backend (Convex)

- Convex is a hosted backend: a database plus server functions, written in TypeScript in `convex/`.
- Status: installed with an empty schema. No tables, functions, or cloud project exist yet.

## First-time setup (a person must do this)

- Install packages: `npm install` (needs Node 20 or newer).
- Run `npm run dev` (same as `npx convex dev`). It asks you to log in to Convex and creates a dev project in the cloud.
- That step writes `.env.local` with the project address. Git ignores it; don't commit it.
- Leave `npm run dev` running while you work. It pushes changes in `convex/` and refreshes `convex/_generated/`.

## Files

- `convex/schema.ts` — table definitions. Empty for now.
- `convex/_generated/` — written by Convex tools. Commit it; don't edit it by hand.
- `convex/_generated/ai/guidelines.md` — Convex's rules for writing Convex code. Agents read this first.
- `.agents/skills/` and `.claude/skills/` — Convex's task guides for coding agents, same content in two places. `skills-lock.json` pins their version.

## Updating the AI files

- Run `npx convex ai-files install`. The skills step needs Node 22 or newer; on Node 20 it fails while still writing the guidelines.
- The command also adds a Convex block to `CLAUDE.md`. Delete that copy: `CLAUDE.md` already loads `AGENTS.md`, which keeps the block.
- After it runs, check that `convex/_generated/ai/guidelines.md` and `.agents/skills/` both exist.

## Agent tooling

- Claude Code users can add the Convex plugin: `claude plugin install convex@claude-plugins-official --scope user`.
