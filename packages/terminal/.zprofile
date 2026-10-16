# Initialize portable login paths and optional machine-specific settings.
source "${${(%):-%N}:A:h}/.config/dotfiles/zsh/lib/environment.zsh"
if [[ -r "$XDG_CONFIG_HOME/dotfiles/login.zsh" ]]; then
  source "$XDG_CONFIG_HOME/dotfiles/login.zsh"
fi
