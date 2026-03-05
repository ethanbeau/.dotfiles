#!/usr/bin/env bash
echo "🔄 Updating System..."

# Update Homebrew and Upgrade all packages/casks
echo "🍺 Updating Homebrew..."
brew update
brew upgrade

# Cleanup outdated Homebrew downloads
echo "🧹 Cleaning up Homebrew..."
brew cleanup

# Update macOS software (optional)
# echo "🍎 Checking for macOS updates..."
# softwareupdate -i -a

echo "✅ System Updated!"
