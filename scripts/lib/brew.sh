#!/usr/bin/env bash

source "$DOTFILES_DIR/packages/terminal/.config/dotfiles/zsh/lib/homebrew.sh"
dotfiles_homebrew_init || true

brew_manifests() {
  BREWFILES=("$DOTFILES_DIR/manifests/macos/base.Brewfile")
  local group
  for group in development containers utilities; do
    if has_extra "$group"; then BREWFILES+=("$DOTFILES_DIR/manifests/macos/$group.Brewfile"); fi
  done
}

check_packages() {
  brew_manifests
  if ! command -v brew >/dev/null; then report 'Homebrew is missing'; return 0; fi
  local manifest
  for manifest in "${BREWFILES[@]}"; do
    if ! HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --file="$manifest"; then report "Missing packages in $manifest"; fi
  done
}

manage_packages() {
  local action="$1" manifest
  if ! command -v brew >/dev/null; then
    if [[ "$action" == update ]]; then die 'Run setup to install Homebrew first'; fi
    if (( DRY_RUN )); then
      note 'Would install Homebrew using its official installer'
    else
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      dotfiles_homebrew_init || die 'Homebrew installation did not provide an executable'
    fi
  fi
  brew_manifests
  if [[ "$action" == update ]]; then run brew update; fi
  for manifest in "${BREWFILES[@]}"; do
    if ! run env NONINTERACTIVE=1 brew bundle --file="$manifest"; then
      report "Homebrew install failed for $manifest; rerun after resolving the errors"
    fi
  done
  if [[ "$action" == update ]]; then
    run brew upgrade
    run brew cleanup
  fi
}
