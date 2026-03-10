#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"

echo "🔗 Symlinking dotfiles with Stow..."
cd "$DOTFILES_DIR" || exit
stow -v --adopt --restow --target="$HOME" .

echo "✅ Stow complete."
