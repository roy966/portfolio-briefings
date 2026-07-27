#!/usr/bin/env bash
# Publish dashboard to GitHub Pages. Tolerates OneDrive lock warnings.
set -u
cd "$(dirname "$0")" || exit 0
[ -f ../briefings.html ] && cp ../briefings.html index.html
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "publish: not a git repo"; exit 0; }
git add -A 2>/dev/null
git commit -m "refresh $(date -u +%FT%TZ)" >/dev/null 2>&1 || true
if git remote get-url origin >/dev/null 2>&1; then
  for i in 1 2 3; do
    if git push origin main >/dev/null 2>&1; then echo "publish: pushed"; exit 0; fi
    echo "publish: push retry $i"; sleep 3
  done
  echo "publish: push failed after retries"
else
  echo "publish: no origin remote"
fi
