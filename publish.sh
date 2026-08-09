#!/usr/bin/env bash
# Portfolio Briefings -> GitHub Pages publisher.
# OneDrive corrupts in-place .git folders, so ALL git work happens in a fresh
# clone under /var/tmp. Nothing is written to the OneDrive .git directory.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../briefings.html"
WORK="/var/tmp/pb-publish-$$"

[ -f "$SRC" ] || { echo "publish: FAILED — briefings.html not found at $SRC"; exit 1; }

# Recover the authenticated remote URL from the local repo config.
REMOTE=$(git -C "$HERE" remote get-url origin 2>/dev/null || true)
[ -n "$REMOTE" ] || { echo "publish: FAILED — no origin remote configured"; exit 1; }
TOKEN=$(printf '%s' "$REMOTE" | sed -nE 's|.*//[^:]+:([^@]+)@.*|\1|p')
redact(){ if [ -n "${TOKEN:-}" ]; then sed -E "s/${TOKEN}/<TOKEN>/g"; else cat; fi; }

rm -rf "$WORK"
if ! git clone -q "$REMOTE" "$WORK" 2>&1 | redact; then
  echo "publish: FAILED — clone failed"; rm -rf "$WORK"; exit 1
fi
[ -d "$WORK/.git" ] || { echo "publish: FAILED — clone produced no repo"; rm -rf "$WORK"; exit 1; }

cp -f "$SRC" "$WORK/index.html"
[ -f "$HERE/.nojekyll" ] && cp -f "$HERE/.nojekyll" "$WORK/.nojekyll" 2>/dev/null || true
cp -f "$HERE/publish.sh" "$WORK/publish.sh" 2>/dev/null || true

cd "$WORK" || { echo "publish: FAILED — cannot enter clone"; exit 1; }
git config user.email "roy@glilotcapital.com"
git config user.name "Portfolio Briefings Bot"
git add -A 2>/dev/null

if git diff --cached --quiet 2>/dev/null; then
  SHA=$(git rev-parse HEAD)
  echo "publish: already current, nothing to push ($SHA)"
  cd /; rm -rf "$WORK"; exit 0
fi

git commit -q -m "refresh $(date -u +%FT%TZ)" 2>&1 | redact

PUSHED=0
for i in 1 2 3; do
  if git push -q origin main 2>&1 | redact; then PUSHED=1; break; fi
  sleep 3
done

LOCAL=$(git rev-parse HEAD 2>/dev/null)
REMOTE_SHA=$(git ls-remote origin main 2>/dev/null | awk '{print $1}')
cd /; rm -rf "$WORK"

if [ -n "$LOCAL" ] && [ "$LOCAL" = "$REMOTE_SHA" ]; then
  echo "publish: VERIFIED pushed $LOCAL"
  exit 0
fi
echo "publish: FAILED — remote ($REMOTE_SHA) does not match local ($LOCAL)"
exit 1
