unalias ga 2>/dev/null || true

ga() {
  local -a files

  if (( $# )); then
    git add "$@" || return
    print 'Files staged successfully.'
    git status -s
    return
  fi

  files=("${(@0)$(
    git ls-files -z --modified --others --exclude-standard |
      fzf --read0 --print0 --multi --select-1 --exit-0 \
        --prompt='Stage files (TAB select, ENTER stage) > ' \
        --preview='git diff --color=always -- {} | delta'
  )}")

  (( ${#files} )) || return 0
  [[ -n "${files[1]-}" ]] || return 0

  git add -- "${files[@]}" || return
  print 'Files staged successfully.'
  git status -s
}
