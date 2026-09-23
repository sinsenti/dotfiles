#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <repo-path> <pr-number>" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
repo_path=$1
pr_number=$2
[[ $pr_number =~ ^[0-9]+$ ]] || usage

for cmd in git tmux pi; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Required command not found: $cmd" >&2
    exit 1
  }
done

repo_root=$(git -C "$repo_path" rev-parse --show-toplevel 2>/dev/null) || {
  echo "Not a Git checkout: $repo_path" >&2
  exit 1
}
repo_root=$(cd "$repo_root" && pwd -P)
git -C "$repo_root" remote get-url origin >/dev/null 2>&1 || {
  echo "The checkout has no 'origin' remote: $repo_root" >&2
  exit 1
}

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gh-dash-review.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT
patch_file="$tmp_dir/unstaged.patch"
untracked_file="$tmp_dir/untracked.list"
git -C "$repo_root" diff --binary --no-ext-diff -- > "$patch_file"
git -C "$repo_root" ls-files --others --exclude-standard -z > "$untracked_file"

stamp="$(date -u +%Y%m%d-%H%M%S)-$$"
branch="review-pr-${pr_number}-${stamp}"
worktree="$repo_root/.claude/worktrees/$branch"

# Fetch the PR's head without checking it out or changing the root worktree.
git -C "$repo_root" fetch --no-tags origin "refs/pull/${pr_number}/head"
mkdir -p -- "$repo_root/.claude/worktrees"
git -C "$repo_root" worktree add -b "$branch" "$worktree" FETCH_HEAD

# Apply only unstaged tracked edits; copy untracked (non-ignored) files as-is.
if [[ -s $patch_file ]]; then
  if ! git -C "$worktree" apply --3way --binary "$patch_file"; then
    echo "Could not apply the root checkout's unstaged changes cleanly." >&2
    echo "The review worktree was kept at: $worktree" >&2
    exit 1
  fi
fi
while IFS= read -r -d '' relative_path; do
  destination="$worktree/$relative_path"
  mkdir -p -- "$(dirname -- "$destination")"
  cp -a -- "$repo_root/$relative_path" "$destination"
done < "$untracked_file"

echo "Review branch: $branch"
echo "Worktree: $worktree"
tmux new-window -c "$worktree" -n "R-PR-${pr_number}" \
  "exec pi 'Review this branch. You can use parallel agents and subagents if it makes sense.'"
