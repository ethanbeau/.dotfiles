# Core environment and shell behavior
source "$HOME/.dotfiles/zsh/lib/environment.zsh"

# Load local function definitions directly.
for function_file in "$HOME/.dotfiles/zsh/functions/"*.zsh; do
  source "$function_file"
done

source "$HOME/.dotfiles/zsh/aliases.zsh"
source "$HOME/.dotfiles/zsh/interactive.zsh"
source "$HOME/.dotfiles/zsh/completions.zsh"
source "$HOME/.dotfiles/zsh/local.zsh"
