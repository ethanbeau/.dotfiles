# Shared by Bash setup and Zsh startup.
dotfiles_homebrew_init() {
  local brew_bin
  if [ -n "${HOMEBREW_PREFIX:-}" ] && command -v brew >/dev/null 2>&1; then
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    brew_bin="$(command -v brew)"
  elif [ -x /opt/homebrew/bin/brew ]; then
    brew_bin=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    brew_bin=/usr/local/bin/brew
  else
    return 1
  fi
  local shellenv
  shellenv="$("$brew_bin" shellenv)" || return 1
  eval "$shellenv"
}
