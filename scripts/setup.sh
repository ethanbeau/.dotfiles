#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Mac Setup..."

# 1. Install Homebrew if it isn't installed
if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 2. Install all apps and dependencies from the Brewfile
echo "📦 Installing from Brewfile..."
NONINTERACTIVE=1 brew bundle --verbose --file="$HOME/.dotfiles/Brewfile"
echo "✅ Brewfile install complete."

# 3. Create the real .config directory to prevent Stow tree folding
echo "📁 Preparing .config directory..."
mkdir -p "$HOME/.config"

# 4. Stow all dotfiles (adopt existing files, then restow links)
echo "🔗 Symlinking dotfiles with Stow..."
cd "$HOME/.dotfiles" || exit
stow -v --adopt --restow --target="$HOME" .

echo "✅ Setup Complete! Please restart your terminal."
