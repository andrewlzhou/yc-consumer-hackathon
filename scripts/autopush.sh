#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p build
log=build/autopush.log
pidfile=build/autopush.pid

say() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$log"; }

# One pass: push main only when it is ahead of GitHub and not behind. Never merges or forces.
push_once() {
  git fetch -q origin || { say "fetch failed"; return; }
  [ "$(git symbolic-ref -q --short HEAD)" = main ] || return
  read -r ahead behind < <(git rev-list --left-right --count main...origin/main)
  if [ "$behind" -gt 0 ]; then
    [ "$ahead" -gt 0 ] && say "skip: diverged ($ahead ahead, $behind behind); pull by hand" \
      || say "skip: behind origin/main by $behind; pull by hand"
  elif [ "$ahead" -gt 0 ]; then
    if out=$(git push origin main 2>&1); then say "pushed $ahead commit(s)"; else say "push failed: $out"; fi
  fi
}

if [ -n "${AUTOPUSH_ONCE:-}" ]; then push_once; exit 0; fi

old=$(cat "$pidfile" 2>/dev/null)
if [ -n "$old" ] && ps -p "$old" -o command= 2>/dev/null | grep -q autopush.sh; then
  echo "autopush already running (pid $old)"; exit 1
fi
echo $$ > "$pidfile"
trap '[ "$(cat "$pidfile" 2>/dev/null)" = $$ ] && rm -f "$pidfile"' EXIT
trap 'exit 0' TERM INT

# Push committed work on main to GitHub every five minutes (Andrew, 2026-11-15).
while true; do
  push_once
  sleep 300 & wait $!
done
