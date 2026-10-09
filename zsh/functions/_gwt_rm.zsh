# Complete branch names that belong to existing worktrees for gwt-rm.
_gwt_rm() {
  local repo_root line worktree_path=""
  local -a branches
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return
  while IFS= read -r line; do
    case "$line" in
      'worktree '*) worktree_path="${line#worktree }" ;;
      'branch refs/heads/'*)
        [[ "$worktree_path" == "$repo_root" ]] && continue
        branches+=( "${line#branch refs/heads/}" )
        ;;
    esac
  done < <(git -C "$repo_root" worktree list --porcelain)
  compadd -Q -- $branches
}
