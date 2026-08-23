# ⚡ .dotfiles

ethanbeau's personal macOS dotfiles managed with Homebrew + GNU Stow.

## Quick setup

```bash
cd ~/.dotfiles
bash scripts/setup.sh
```

What `scripts/setup.sh` does:

- Installs Homebrew (if missing)
- Installs packages and apps from `Brewfile`
- Imports Vorssaint preferences from `settings/vorssaint-settings.plist`
- Creates `~/.config`
- Symlinks dotfiles into `$HOME` with Stow

## Update everything

```bash
cd ~/.dotfiles
bash scripts/update.sh
```

What `scripts/update.sh` does:

- `brew update`
- `brew upgrade`
- `brew cleanup`

## Structure

- `Brewfile` — CLI tools, taps, and apps
- `settings/vorssaint-settings.plist` — Vorssaint preferences
- `scripts/setup.sh` — first-time machine bootstrap
- `scripts/update.sh` — routine package refresh

## Notes

- Target platform: macOS
- Dotfiles are symlinked into `$HOME`
