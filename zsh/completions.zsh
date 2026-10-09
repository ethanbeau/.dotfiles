# Register local Git worktree completions after compinit has loaded compdef.
if (( $+functions[compdef] )); then
  autoload -Uz _gwt _gwt_rm
  compdef _gwt gwt
  compdef _gwt_rm gwt-rm
fi
