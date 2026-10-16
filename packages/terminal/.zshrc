# Load shared shell modules from the terminal package.
typeset -g DOTFILES_ZSH_DIR="${${(%):-%N}:A:h}/.config/dotfiles/zsh"
source "$DOTFILES_ZSH_DIR/lib/environment.zsh"
source "$DOTFILES_ZSH_DIR/local.zsh"

if [[ -o interactive ]]; then
  for function_file in "$DOTFILES_ZSH_DIR/functions/"*.zsh(N); do
    source "$function_file"
  done
  if [[ "$OSTYPE" == darwin* ]]; then
    for function_file in "$DOTFILES_ZSH_DIR/functions/macos/"*.zsh(N); do
      source "$function_file"
    done
  fi
  unset function_file
  source "$DOTFILES_ZSH_DIR/aliases.zsh"
  source "$DOTFILES_ZSH_DIR/interactive.zsh"
  source "$DOTFILES_ZSH_DIR/completions.zsh"
fi

# Local overrides are intentionally outside the checkout.
if [[ -r "${XDG_CONFIG_HOME}/dotfiles/local.zsh" ]]; then
  source "${XDG_CONFIG_HOME}/dotfiles/local.zsh"
fi
