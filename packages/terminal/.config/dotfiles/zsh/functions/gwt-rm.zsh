# Remove a clean worktree by branch name or path.
gwt-rm() {
  emulate -L zsh
  setopt local_options no_unset

  if (( $# != 1 )); then
    print -u2 'Usage: gwt-rm <branch-or-worktree-path>'
    return 2
  fi

  local repo_root worktree_path candidate repo_name
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    print -u2 'gwt-rm: run this command inside a Git repository'
    return 1
  }
  repo_name="${repo_root:t}"
  candidate="$1"
  if [[ "$candidate" == /* ]]; then
    worktree_path="${candidate:A}"
  else
    worktree_path="${GIT_WORKTREE_DIR:-$HOME/code/projects/.worktrees}/${repo_name}-${candidate//\//-}"
  fi

  if [[ ! -d "$worktree_path/.git" && ! -f "$worktree_path/.git" ]]; then
    print -u2 "gwt-rm: not a Git worktree: $worktree_path"
    return 1
  fi

  local worktree_status
  worktree_status="$(git -C "$worktree_path" status --porcelain --untracked-files=all)" || return
  if [[ -n "$worktree_status" ]]; then
    print -u2 "gwt-rm: refusing to remove a dirty worktree: $worktree_path"
    print -u2 -- "$worktree_status"
    return 1
  fi

  git -C "$repo_root" worktree remove "$worktree_path"
}
