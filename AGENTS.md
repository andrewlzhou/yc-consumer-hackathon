# Working in YC Consumer Hackathon

- These rules apply to every agent and contributor, including Codex and Claude.
- Read [README.md](README.md), [current decisions](docs/project/decisions.md), and the relevant [module docs](docs/README.md) before editing.
- Read any nested `AGENTS.md` before changing its directory. Keep shared rules here; add scoped rules only when needed.
- Inspect the working tree first. Preserve other people's changes and existing code.

## Product

- Tell a shopper whether a product is worth buying right now, from its price history, competing products, and how real its discount is. The [README](README.md) holds the full product description.
- Work falls into three workstreams: backend (historical price data), surfacing (when and how the assistant reaches the user), and UI/UX (how it looks and feels).
- Convex is the backend. The client platform is not chosen yet; the planned entry points are iPhone ones (Shortcut, Control Center, Safari extension, share menu).
- The price-history backend should be mostly deterministic: the same data gives the same numbers.
- Every analysis ends in exactly one verdict: BUY NOW, WAIT, CONSIDER ALTERNATIVE, or INVESTIGATE. Use INVESTIGATE when the data is too thin to support the others.
- Forecasts show a predicted range and a confidence level, not a bare guess.
- Treat proposed features as plans until implemented. Never imply in docs or reports that a placeholder is working.

## Code

- Consider the simplest approach that fully delivers the requested behavior and quality. Simplicity must not reduce the result.
- Use clear names, small functions, and sensible file boundaries. Extract repeated or meaningful logic; avoid speculative frameworks and needless layers.
- Do not write docstrings. Use brief comments above functions when their purpose or connection to the feature needs explaining; comment tricky lines sparingly.
- Add dependencies only when they solve a real need. Never commit credentials or user data.
- Verify the affected behavior with focused checks. Add tests for meaningful behavior and regressions; avoid tests that just repeat the implementation.

## Remember instructions

- Before finishing, distill every new user instruction into the appropriate current document. Do this for instructions received by any agent, from anyone on the project.
- Put lasting, repo-wide rules in this file; module conventions in `docs/<module>/`; product changes in the root README; architectural choices and open questions in `docs/project/decisions.md`.
- Capture task-specific constraints and their outcome in that session's change note. Do not turn one-off requests into permanent rules.
- Update the existing rule when an instruction changes it. Keep one authoritative version; let Git and change notes preserve history.
- A clear new user instruction replaces an older convention. Ask only when a real conflict remains unresolved; never silently discard an instruction from the project owners.
- Keep `CLAUDE.md` as a bridge to this file, without a second copy of the rules.

## Documentation

- Keep the root README human-readable and relatively non-technical: what the product is, its current state, and how the idea is evolving.
- Put documentation under root `docs/`, grouped by module. Keep each Markdown file there at most 60 lines; split by topic when needed.
- Use short bullets, plain words, and a conversational tone. Explain unfamiliar concepts before using them. Skip fluff and assumed specialist knowledge.
- Document actual behavior and runnable commands. Update affected docs in the same session as code changes.

## Finish every session

- Update current instructions, decisions, and affected module docs first. This is required even when the session only changes documentation.
- Add a unique, short note at `docs/changes/YYYY/MM/DD-short-topic.md` using [the format](docs/changes/README.md). Include instructions, changes, checks, and loose ends; be honest about anything unverified.
- Never rewrite or delete an earlier session's note. Correct it in a new note; edit your own note while its session is in progress.
- Keep old logs out of routine startup context. Search them only for relevant history. Git stores the full diffs.
- Run `python3 scripts/check_docs.py`, then the relevant checks in the module docs. CI requires a session note added or updated in each push to `main` or pull request; later pushes in the same session may update that session's note.
- Review the final diff for unrelated changes and secrets. Report the outcome, verification, and any remaining limitation.
- Commit after each feature or fix is built and its checks pass, in its own commit with a clear message, so the tree never holds several sessions of uncommitted work. Keep unrelated changes in separate commits. Push when the user asks. Never force-push or overwrite remote work to get a push through.

<!-- convex-ai-start -->

This project uses [Convex](https://convex.dev) as its backend.

When working on Convex code, **always read
`convex/_generated/ai/guidelines.md` first** for important guidelines on
how to correctly use Convex APIs and patterns. The file contains rules that
override what you may have learned about Convex from training data.

Convex agent skills for common tasks can be installed by running
`npx convex ai-files install`.

<!-- convex-ai-end -->
