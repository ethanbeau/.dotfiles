# Create a worktree for an existing branch or a new branch.
gwt() {
  emulate -L zsh
  setopt local_options no_unset

  if (( $# < 1 || $# > 2 )); then
    print -u2 'Usage: gwt <branch> [start-point]'
    return 2
  fi

  local branch="$1"
  local start_point="${2:-}"
  local repo_root repo_name worktree_path hook include_path
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    print -u2 'gwt: run this command inside a Git repository'
    return 1
  }
  repo_name="${repo_root:t}"
  if [[ "$branch" == -* || "$branch" == *..* || "$branch" == *$'\n'* ]] || ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
    print -u2 "gwt: invalid branch name: $branch"
    return 2
  fi

  worktree_path="${GIT_WORKTREE_DIR:-$HOME/code/projects/.worktrees}/${repo_name}-${branch//\//-}"
  if [[ -e "$worktree_path" ]]; then
    print -u2 "gwt: path already exists: $worktree_path"
    return 1
  fi

  command mkdir -p -- "${worktree_path:h}" || return

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$worktree_path" "$branch" || return
  elif git show-ref --verify --quiet "refs/remotes/$branch"; then
    local local_branch="${branch#*/}"
    if git show-ref --verify --quiet "refs/heads/$local_branch"; then
      local_branch="${branch//\//-}"
    fi
    git worktree add --track -b "$local_branch" "$worktree_path" "$branch" || return
  elif [[ -n "$start_point" ]]; then
    git worktree add -b "$branch" "$worktree_path" "$start_point" || return
  else
    git worktree add -b "$branch" "$worktree_path" || return
  fi

  # Copy only explicit local files listed in .gwtinclude. Never copy local
  # virtual environments or Rust build output into another worktree.
  if [[ -f "$repo_root/.gwtinclude" ]]; then
    while IFS= read -r include_path || [[ -n "$include_path" ]]; do
      include_path="${include_path%%#*}"
      include_path="${include_path##[[:space:]]#}"
      include_path="${include_path%%[[:space:]]#}"
      [[ -z "$include_path" ]] && continue
      if [[ "$include_path" == /* || "$include_path" == .. || "$include_path" == ../* || "$include_path" == */../* || "$include_path" == .venv* || "$include_path" == target* ]]; then
        print -u2 "gwt: skipping unsafe or generated path in .gwtinclude: $include_path"
        continue
      fi
      if [[ -e "$repo_root/$include_path" ]]; then
        command mkdir -p -- "$worktree_path/${include_path:h}" || return
        command rsync -a -- "$repo_root/$include_path" "$worktree_path/${include_path:h}/" || return
      fi
    done < "$repo_root/.gwtinclude"
  fi

  hook="$repo_root/.gwt-post-create"
  if [[ -f "$hook" && -x "$hook" ]]; then
    (cd "$worktree_path" && GWT_SOURCE="$repo_root" GWT_WORKTREE="$worktree_path" "$hook") || return
  elif [[ -f "$worktree_path/pyproject.toml" ]] && (( $+commands[uv] )); then
    (cd "$worktree_path" && uv sync) || return
  fi

  print -r -- "$worktree_path"
}
