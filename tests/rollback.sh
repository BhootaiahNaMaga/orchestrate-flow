#!/usr/bin/env bash
# Checks the LOOP.md "Regress" restore against the reviewer's case: a later commit
# modifies tracked.txt and adds extra.txt; restoring must match the best commit exactly.
# Usage: bash tests/rollback.sh [old]   ("old" runs the previous, buggy command and should fail)
set -euo pipefail

repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
cd "$repo"
git init -q
git config user.name test && git config user.email test@example.invalid

mkdir -p tb && echo v1 > tb/tracked.txt && echo keep > outside.txt
git add . && git commit -qm best
best=$(git rev-parse HEAD)

echo v2 > tb/tracked.txt && echo new > tb/extra.txt && echo scratch > tb/untracked.log
git add tb/tracked.txt tb/extra.txt && git commit -qm "round 2 (regressed)"

scope=tb
if [ "${1:-}" = old ]; then
  git checkout "$best" -- .
else
  git restore --source="$best" --staged --worktree -- "$scope"
  git clean -fdq -- "$scope"
fi
git commit -qm "revert to best (round 2)" || true

if git diff --quiet "$best" -- "$scope" && [ -z "$(git status --porcelain -- "$scope")" ]; then
  echo "PASS: $scope matches best commit"
else
  echo "FAIL: $scope differs from best commit"; git diff --stat "$best" -- "$scope"; git status --short -- "$scope"
  exit 1
fi
