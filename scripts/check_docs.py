import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHANGE_NOTE = re.compile(r"docs/changes/\d{4}/\d{2}/\d{2}-[a-z0-9-]+\.md")


# Keep current docs small and history split into individual session notes.
def check_lengths() -> list[str]:
    errors = []
    for path in sorted((ROOT / "docs").rglob("*.md")):
        limit = 20 if CHANGE_NOTE.fullmatch(path.relative_to(ROOT).as_posix()) else 60
        count = len(path.read_text().splitlines())
        if count > limit:
            errors.append(
                f"{path.relative_to(ROOT)} has {count} lines; keep it at most {limit}."
            )
    return errors


# Check the whole pushed range, including the first commit in an empty repo.
def check_change_note(base: str) -> list[str]:
    if set(base) == {"0"}:
        base = subprocess.check_output(
            ["git", "hash-object", "-t", "tree", "--stdin"],
            input="",
            text=True,
            cwd=ROOT,
        ).strip()
    changed = subprocess.check_output(
        ["git", "diff", "--name-only", base, "HEAD", "--"], text=True, cwd=ROOT
    ).splitlines()
    if not changed:
        return []
    written = subprocess.check_output(
        ["git", "diff", "--name-only", "--diff-filter=AM", base, "HEAD", "--"],
        text=True,
        cwd=ROOT,
    ).splitlines()
    if any(CHANGE_NOTE.fullmatch(path) for path in written):
        return []
    return [
        "Add or update this session's note at docs/changes/YYYY/MM/DD-short-topic.md."
    ]


# Local runs check length; CI also supplies the base commit to check freshness.
def main() -> None:
    parser = argparse.ArgumentParser(description="Check short docs and session notes.")
    parser.add_argument(
        "--base", help="Git commit before these changes; CI supplies this."
    )
    args = parser.parse_args()
    errors = check_lengths()
    if args.base:
        errors.extend(check_change_note(args.base))
    if errors:
        raise SystemExit("\n".join(errors))
    print("Documentation checks passed.")


if __name__ == "__main__":
    main()
