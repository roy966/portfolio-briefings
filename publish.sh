#!/usr/bin/env bash
# Robust GitHub Pages publish. Goal: make origin/main == local main.
# Tolerates OneDrive .git lock warnings; never writes to /tmp; always tries to push.
set -u
cd "$(dirname "$0")" || exit 0
[ -f ../briefings.html ] && cp -f ../briefings.html index.html
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "publish: not a git repo"; exit 0; }
git remote get-url origin >/dev/null 2>&1 || { echo "publish: no origin remote"; exit 0; }
clean_locks(){ rm -f .git/index.lock .git/HEAD.lock .git/refs/heads/main.lock .git/objects/maintenance.lock 2>/dev/null || true; }
clean_locks
git add -A 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  for c in 1 2 3; do git commit -m "refresh $(date -u +%FT%TZ)" >/dev/null 2>&1 && break; clean_locks; sleep 2; done
fi
for i in 1 2 3 4 5; do
  LOCAL=$(git rev-parse main 2>/dev/null)
  REMOTE=$(git ls-remote origin main 2>/dev/null | awk '{print $1}')
  if [ -n "$LOCAL" ] && [ "$LOCAL" = "$REMOTE" ]; then echo "publish: up to date ($LOCAL)"; exit 0; fi
  if git push origin main >/dev/null 2>&1; then echo "publish: pushed ($LOCAL)"; exit 0; fi
  echo "publish: push retry $i"; clean_locks; sleep 3
done
echo "publish: push FAILED (local=$LOCAL remote=$REMOTE)"; exit 1
