# 2026-11-15 — Repository foundation

- Author: Claude (Opus 5.5), requested by Andrew.
- Instructions: start the YC consumer hackathon repo from project-template, named only, with no project work yet.
- Instructions: Andrew chose the product (AI shopping assistant: buy now or wait) and its three workstreams. Saved in the README, the Product section of `AGENTS.md`, and [decisions](../../../project/decisions.md).
- Instructions: Andrew asked for automatic pushes every five minutes. Saved in `AGENTS.md` and [working together](../../../project/working-together.md).
- Changed: copied the template and set the project name; later filled the product description, agent product rules, owner decisions, and open questions.
- Changed: added `scripts/autopush.sh`, which pushes committed `main` work every five minutes and skips when GitHub is ahead.
- Checks: `python3 scripts/check_docs.py` passed, with and without `--base` set to the empty tree. For the push script: `bash -n` passed, a one-pass run (`AUTOPUSH_ONCE=1`) while in sync did nothing, and a second copy refused to start.
- Next: settle the open questions in decisions (price data source, client platform, competitor matching).
