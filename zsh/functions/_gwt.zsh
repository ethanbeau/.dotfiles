# Complete existing local and remote branch names for gwt.
_gwt() {
  local -a branches
  branches=( ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null | sed '/\/HEAD$/d' | sort -u)"} )
  compadd -Q -- $branches
}
