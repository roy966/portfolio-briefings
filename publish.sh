#!/usr/bin/env bash
set -u
cd "$(dirname "$0")" || exit 0
[ -f ../briefings.html ] && cp ../briefings.html index.html
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "publish: not a git repo"; exit 0; }
git add -A
git commit -m "refresh $(date -u +%FT%TZ)" >/dev/null 2>&1 || echo "publish: nothing new"
if git remote get-url origin >/dev/null 2>&1; then
  for i in 1 2 3; do git push -q origin main 2>/dev/null && { echo "publish: pushed"; break; } || { echo "publish: retry $i"; sleep 3; }; done
else echo "publish: no origin remote"; fi
