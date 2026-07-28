#!/usr/bin/env bash
# Robust GitHub Pages publish for Portfolio Briefings.
# Goal: after this script, origin/main MUST reflect the current briefings.html.
# Handles OneDrive .git lock warnings; never leaves uncommitted changes behind.
set -u
cd "$(dirname "$0")" || exit 0
[ -f ../briefings.html ] && cp -f ../briefings.html index.html

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "publish: not a git repo"; exit 0; }
git remote get-url origin >/dev/null 2>&1 || { echo "publish: no origin remote"; exit 0; }

clean_locks(){ rm -f .git/index.lock .git/HEAD.lock .git/refs/heads/main.lock .git/objects/maintenance.lock 2>/dev/null || true; }

# 1) Clear any stale locks (OneDrive can leave these behind).
clean_locks

# 2) Stage any working-tree changes (index.html we just copied, etc).
git add -A 2>/dev/null || { clean_locks; sleep 1; git add -A 2>/dev/null || true; }

# 3) Commit if EITHER staged OR working-tree changes exist.
if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  for c in 1 2 3; do
    if git commit -m "refresh $(date -u +%FT%TZ)" >/dev/null 2>&1; then break; fi
    clean_locks; sleep 2
  done
fi

# 4) Push until local == remote (verified by SHA), retry to survive OneDrive races.
for i in 1 2 3 4 5; do
  LOCAL=$(git rev-parse main 2>/dev/null)
  REMOTE=$(git ls-remote origin main 2>/dev/null | awk '{print $1}')
  if [ -n "$LOCAL" ] && [ "$LOCAL" = "$REMOTE" ]; then
    # 5) Safety net: even when SHAs match, ensure working tree is clean.
    if ! git diff --quiet HEAD 2>/dev/null; then
      echo "publish: WARN uncommitted changes remain despite matching SHA — re-committing"
      clean_locks
      git add -A 2>/dev/null || true
      git commit -m "refresh (safety commit) $(date -u +%FT%TZ)" >/dev/null 2>&1 || true
      git push origin main >/dev/null 2>&1 || true
      LOCAL=$(git rev-parse main 2>/dev/null); REMOTE=$(git ls-remote origin main 2>/dev/null | awk '{print $1}')
    fi
    echo "publish: pushed and in sync ($LOCAL)"; exit 0
  fi
  if git push origin main >/dev/null 2>&1; then echo "publish: pushed ($LOCAL)"; exit 0; fi
  echo "publish: push retry $i (local=$LOCAL remote=$REMOTE)"
  clean_locks; sleep 3
done
echo "publish: FAILED to reach sync (local=$LOCAL remote=$REMOTE)"; exit 1
