#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VORSSAINT_SETTINGS="$DOTFILES_DIR/settings/vorssaint-settings.plist"

echo "🚀 Starting Mac Setup..."

# 1. Install Homebrew if it isn't installed
if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 2. Install all apps and dependencies from the Brewfile
echo "📦 Installing from Brewfile..."
NONINTERACTIVE=1 brew bundle --verbose --file="$DOTFILES_DIR/Brewfile"
echo "✅ Brewfile install complete."

# 3. Import Vorssaint preferences after its app has been installed.
if [[ -f "$VORSSAINT_SETTINGS" ]]; then
    echo "⚙️  Importing Vorssaint settings..."
    plutil -lint "$VORSSAINT_SETTINGS"
    (
        VORSSAINT_DEFAULTS="$(mktemp)"
        trap 'rm -f "$VORSSAINT_DEFAULTS"' EXIT
        plutil -extract settings xml1 -o "$VORSSAINT_DEFAULTS" "$VORSSAINT_SETTINGS"
        defaults import com.vorssaint.utils "$VORSSAINT_DEFAULTS"
    )
    echo "✅ Vorssaint settings imported."
fi

# 4. Create the real .config directory to prevent Stow tree folding
echo "📁 Preparing .config directory..."
mkdir -p "$HOME/.config"

# 5. Stow all dotfiles (adopt existing files, then restow links)
echo "🔗 Symlinking dotfiles with Stow..."
cd "$DOTFILES_DIR" || exit
stow -v --adopt --restow --target="$HOME" .

echo "✅ Setup Complete! Please restart your terminal."
