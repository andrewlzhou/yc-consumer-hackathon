# How the backend crew works

- Repo copy of the Captain's crew rules (CREW.md in Captain Ruhaan's drive). If they disagree, report it so both get fixed.
- Owner: Ruhaan Singh. Several agent threads build the backend in parallel under one Captain.

## How to resume

- Start from [status.md](status.md): each workstream's working state, next steps, and gotchas, kept current per push.

## Branch and pushing

- All backend work lands on `ruhaan_backend`, forked from `main`. Never commit to `main`, never merge into it,
  never force-push, never rewrite pushed history.
- After every step whose checks pass: `git pull --rebase origin ruhaan_backend`, then `git push origin HEAD:ruhaan_backend`.
  Small commits with clear messages.
- Unfinished work still gets pushed before a thread stops, on `ruhaan_backend-wip-<area>`.
- Rebase conflicts: keep both sides' intent. If the conflict is in another thread's files and unclear, stop and report.
- No pull requests unless the Captain asks; the branch is the integration point.

## Checks before every push

- `npm run typecheck` (TypeScript over `convex/`), `npm test` (vitest + convex-test), `python3 scripts/check_docs.py`.
- A session note under `docs/changes/YYYY/MM/`, docs files at most 60 lines, no docstrings, no secrets.

## File ownership

- Data and retrieval: `convex/schema.ts` (first version), `convex/data/**`, `convex/seed/**`, `convex/lib/contract.ts`,
  `eval/cases*`, `docs/backend/data*.md`, `docs/backend/contract.md`, `docs/backend/orchestration.md`.
- Shopping agent: `convex/agent/**`, `convex/http.ts`, `eval/run*`, `docs/backend/agent*.md`.
- Monitoring: `convex/watchlist/**`, `convex/monitoring/**`, `convex/crons.ts`, `docs/backend/monitoring*.md`.
- `convex/schema.ts` is shared after the first version: each thread adds only its own tables in its own block.
- Changing the [contract](contract.md) is allowed but must be reported to the Captain.

## Credentials and deploys

- Deploy to the shared dev deployment only from a clean clone of the `ruhaan_backend` tip, right after pushing.
  A deploy replaces all functions and drops indexes missing from the deployed schema.
- Local checks: `env -u CONVEX_DEPLOY_KEY -u CONVEX_DEPLOYMENT CONVEX_AGENT_MODE=anonymous npx convex dev`; with the
  deploy key set, anonymous mode is ignored and the push goes to the cloud.
- LLM calls sit behind a small provider interface (OpenAI first) with a deterministic fake for tests.
- Never print secret values. Check `env` for names only.

## Models

- Hard design and reasoning: Claude Opus (high). Routine builds and tests: Claude Sonnet. Cheap lookups: Claude Haiku.
- If Claude is refused or out of quota, switch to OpenAI: gpt-6.1-sol for builds, gpt-6-astra for the hardest
  reasoning, gpt-6-luna for cheap subagents. Don't wait on a dead connection.
- Writing subagents get their own fresh machine and the same push rules.

## Docs follow reality

- The specs are context, not law. When testing shows a better approach, change the code and the doc in the same
  commit, and say what changed and why in the session note.
- Report to the Captain only when done, blocked, needing Ruhaan's decision, or after a contract change.
