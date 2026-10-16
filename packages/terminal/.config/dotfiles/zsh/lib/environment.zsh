export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
export BAT_THEME="TwoDark"
export GIT_WORKTREE_DIR="${GIT_WORKTREE_DIR:-$HOME/code/projects/.worktrees}"

# Homebrew is only a package source on macOS. Support both CPU architectures.
if [[ "$OSTYPE" == darwin* ]]; then
  export HOMEBREW_NO_ENV_HINTS=1
  source "${${(%):-%N}:A:h}/homebrew.sh"
  dotfiles_homebrew_init || true
  export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
else
  export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
fi

typeset -U PATH path
path=("$HOME/.local/bin" "$VOLTA_HOME/bin" "$PNPM_HOME" $path)
export PATH

if (( $+commands[nvim] )); then
  export EDITOR=nvim
else
  export EDITOR=vi
fi
typeset -g DOTFILES_HAS_BAT=0 DOTFILES_HAS_FD=0
command bat --version >/dev/null 2>&1 && DOTFILES_HAS_BAT=1
command fd --version >/dev/null 2>&1 && DOTFILES_HAS_FD=1
if (( DOTFILES_HAS_BAT && $+commands[col] )); then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

if [[ -o interactive ]]; then
  HISTFILE="$HOME/.zsh_history"
  HISTSIZE=100000
  SAVEHIST=100000
  setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS SHARE_HISTORY INC_APPEND_HISTORY
  setopt HIST_EXPIRE_DUPS_FIRST HIST_REDUCE_BLANKS HIST_VERIFY
  setopt INTERACTIVE_COMMENTS NO_BEEP
fi
