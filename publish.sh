#!/usr/bin/env bash
# Publish briefings.html -> index.html and push to GitHub Pages.
#
# NOTE: this sandbox's filesystem refuses to unlink/delete files (rm fails with
# "Operation not permitted" even on files it just created), but rename (mv) works.
# git's own lock/tmp-object cleanup uses unlink, so a crashed or overlapping run
# leaves stale .lock files that permanently block every future `git commit`
# while still letting `git push` "succeed" (it just re-pushes the unchanged old
# commit). This script clears stale locks via mv, verifies the commit actually
# happened, and verifies the push actually landed on the remote before claiming
# success.
set -u
cd "$(dirname "$0")" || exit 0

clear_stale_locks() {
  local gitdir=".git"
  [ -d "$gitdir" ] || return 0
  local f ts
  ts="$(date +%s%N)"
  for f in "$gitdir"/index.lock "$gitdir"/HEAD.lock \
           "$gitdir"/refs/heads/main.lock "$gitdir"/refs/remotes/origin/main.lock \
           "$gitdir"/objects/maintenance.lock "$gitdir"/config.lock; do
    [ -e "$f" ] && mv "$f" "$f.stale.$ts" 2>/dev/null
  done
  while IFS= read -r f; do
    mv "$f" "$f.stale.$ts" 2>/dev/null
  done < <(find "$gitdir/objects" -name 'tmp_obj_*' 2>/dev/null)
}

[ -f ../briefings.html ] && cp ../briefings.html index.html

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "publish: not a git repo"; exit 0; }

clear_stale_locks
git add -A

if git diff --cached --quiet; then
  echo "publish: no changes to commit"
else
  commit_ok=0
  for attempt in 1 2; do
    if git commit -m "refresh $(date -u +%FT%TZ)" >/tmp/publish_commit.log 2>&1; then
      commit_ok=1
      break
    fi
    echo "publish: commit attempt $attempt failed, clearing stale locks and retrying"
    cat /tmp/publish_commit.log
    clear_stale_locks
  done
  if [ "$commit_ok" -ne 1 ]; then
    echo "publish: COMMIT FAILED after retries — aborting without pushing"
    exit 1
  fi
fi

local_head="$(git rev-parse HEAD)"

git remote get-url origin >/dev/null 2>&1 || { echo "publish: no origin remote"; exit 0; }

pushed=0
for i in 1 2 3; do
  clear_stale_locks
  if git push origin main >/tmp/publish_push.log 2>&1; then
    pushed=1
    break
  fi
  echo "publish: push retry $i"
  cat /tmp/publish_push.log
  sleep 3
done

if [ "$pushed" -ne 1 ]; then
  echo "publish: PUSH FAILED after retries"
  exit 1
fi

# Don't trust push's own exit code alone (a blocked local ref-update after a
# real push can still exit 0) — confirm the remote tip actually matches.
remote_head="$(git ls-remote origin main 2>/dev/null | awk '{print $1}')"
if [ "$remote_head" = "$local_head" ]; then
  echo "publish: pushed and verified ($local_head)"
else
  echo "publish: WARNING push reported success but remote HEAD ($remote_head) != local HEAD ($local_head)"
  exit 1
fi
