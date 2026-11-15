# Working together

- `AGENTS.md` holds the current shared ground rules. Codex loads that filename; `CLAUDE.md` imports it for Claude Code.
- Other agents should be pointed to `AGENTS.md` when they start. These files are guidance, not a guarantee that every tool follows it.
- Loading behavior: [Codex guidance](https://learn.chatgpt.com/docs/agent-configuration/agents-md) and [Claude Code imports](https://code.claude.com/docs/en/memory#import-additional-files).
- Everyone on the project uses the same tracked files, so conventions travel with the repo instead of living in one chat's memory.
- Pull the latest shared work before starting; inspect local changes before updating a checkout. Don't overwrite someone else's edits.

## When a new instruction arrives

- Record the instruction's useful meaning, not a transcript of the prompt.
- Update `AGENTS.md` for shared rules, the relevant module doc for scoped conventions, or the root README for product direction.
- Put architectural choices in [current decisions](decisions.md). Mark proposals as open until they're actually chosen.
- Keep temporary task constraints in that session's note. Link to the current rule when useful; don't duplicate a whole rule in several places.
- When a rule changes, replace its current wording. The session note records what changed, and Git retains the previous version.

## Before an agent finishes

- Update affected docs and record new instructions before handing the work back.
- Add one unique note under `docs/changes/YYYY/MM/`. See the [format](../changes/README.md).
- Note what changed, what was verified, and what still needs attention. A blocked or unfinished session still gets a note if it changed the repo.
- Run the relevant module checks and `python3 scripts/check_docs.py` from the repo root.
- CI checks document length and requires an added or updated session note in each push to `main` or pull request. Later pushes may update the active session's note; past sessions stay intact.
- CI cannot judge whether a note is complete or whether an old note was edited; the agent must respect the shared rules.

## Keep context small

- Start with current rules, the root README, current decisions, and docs for the module you're touching.
- Don't preload session archives or whole prompt histories. Search dated notes only when their history helps the task.
- Keep full implementation details in code and Git; keep docs focused on what a human needs to understand or run the project.
