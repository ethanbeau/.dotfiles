# Dotfiles

Personal macOS and Linux configs managed with Homebrew or native Linux packages,
and GNU Stow.

## Profiles

| Profile | Packages and configs |
| --- | --- |
| `macos` | `manifests/macos/base.Brewfile`, terminal tools, Mac settings, Ghostty, cmux, and Zed configs |
| `linux-server` | Zsh, completion plugins, Starship, Atuin, fzf, zoxide, eza, bat, dust, fd, ripgrep/rga, Git/delta, lazygit, lazydocker, Neovim, Yazi, and supporting terminal tools |
| `linux-desktop` | Server tools plus Ghostty, Zed, cmux GUI, Bruno, Helium, Fira Code fonts, and clipboard tools |

Linux supports standard Debian, Ubuntu, Fedora, and Arch installations. Immutable
Fedora and distribution derivatives are not supported. Desktop setup requires an
existing GUI. It does not install a desktop environment or change system shortcuts.

Mac packages are defined in `manifests/macos/base.Brewfile`. Zed config is linked on Mac; install the
Zed app with the development extras group.

## Setup

Clone this repository to any persistent location. You can run setup by its path
from any working directory:

```bash
bash /path/to/dotfiles/scripts/setup.sh
```

Setup detects the OS. On the first Linux run, it asks you to select the server or
desktop profile. You can also select a profile explicitly:

```bash
bash scripts/setup.sh --profile linux-server
bash scripts/setup.sh --profile linux-desktop --extras development,utilities
bash scripts/setup.sh --profile macos --extras development
```

Use `--dry-run` to show selections and actions without changing files:

```bash
bash scripts/setup.sh --profile macos --dry-run
```

Profile and extras are stored in `${XDG_STATE_HOME:-~/.local/state}/dotfiles/machine`.
Later commands reuse them. An explicit `--extras` replaces the saved selection;
`--extras none` clears it. Removing an extras group does not uninstall packages.

Setup offers to change your login shell to Zsh once, in an interactive session.
It records your answer locally. Delete the `shell-choice` file beside `machine`
to see the offer again. Noninteractive runs never call `chsh`.

## Optional extras

| Group | Linux | macOS |
| --- | --- | --- |
| `development` | Rust/Cargo, uv, Python, Node/npm, Volta, markdownlint, Vite+, gh, Linear CLI, Watchman | gh, Rust, uv, Vite+, Linear CLI, Watchman, Bruno, Zed; default runtimes stay in `manifests/macos/base.Brewfile` |
| `containers` | Docker Desktop on GUI machines | Docker Desktop |
| `utilities` | FFmpeg, wget | FFmpeg, wget, GrandPerspective, mactop, Fira Code, Helium |

Only available packages from permitted sources are installed. No PostgreSQL
package or service is selected. The containers group is skipped and reported on
Linux servers. Docker Desktop requires the vendor's supported architecture and
KVM setup; setup does not launch it or enable its service.

Mac group manifests are in `manifests/macos/`. Edit a group manifest to change
optional Mac packages.
Linux mappings and fallback sources are in `manifests/linux.psv` (pipe-separated values).

Lazydocker is selected in every default profile and has the shell alias `ld`.
Linux tries native repositories, with the `lazydocker` AUR recipe as an Arch
fallback. Unavailable packages are reported and skipped. Docker itself must be
installed separately or through the containers extras group on desktops.

## Linux package sources

Setup uses apt, dnf, or pacman. It tries configured repositories first. These
explicit fallback sources are permitted:

- Ghostty: matching distribution/architecture `.deb` assets from
  [ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu), or Fedora COPR
  `scottames/ghostty`, as listed in the [Ghostty installation docs](https://ghostty.org/docs/install/binary).
- Helium: its [vendor apt repository or Fedora COPR](https://helium.computer/download),
  or the `helium-browser-bin` AUR recipe.
- Bruno: native `.deb`/`.rpm` assets from
  [usebruno/bruno](https://github.com/usebruno/bruno), or `bruno-bin` from AUR.
- cmux GUI: the official x64 `.deb` from [cmux Linux](https://cmux.com/linux).
  Other platforms are reported as unavailable. The TUI is not substituted.
- Docker Desktop: official native packages and dependency repositories from
  [Docker](https://docs.docker.com/desktop/setup/install/linux/), or its AUR recipe.
- Arch: only the AUR recipes explicitly listed in the manifest. They are built
  with `makepkg` as the current regular user. Setup installs `base-devel` when
  an AUR build is needed. Root runs skip and report AUR packages.

Setup does not install Linux Homebrew, Flatpak, AppImage, Snap, generic binary
installers, or packages through npm/pip/cargo. Existing Neovim plugin and Zed
extension downloads remain enabled. GitHub native assets are checked against
SHA-256 release metadata when the publisher provides it.

Package availability depends on distribution release and architecture. Missing
optional packages and failed optional installations are listed at the end.
Setup fails if it cannot refresh package metadata or install links. A failed
optional installation remains incomplete until you resolve the reported issue
and rerun setup. No repositories are removed when you change profiles.

## Config-only setup and profile changes

```bash
bash scripts/setup.sh --profile linux-server --config-only
bash scripts/stow.sh --profile linux-desktop
```

Linux setup falls back to config-only mode when sudo is unavailable. GNU Stow
must already be installed. Missing tools are reported, and Zsh skips unavailable
plugins and tool aliases. Debian's `batcat` and `fdfind` names are handled by
Linux wrappers in `~/.local/bin`.

Native Neovim packages older than 0.11.2 use basic editor settings instead of
loading incompatible LazyVim plugins. See [LazyVim requirements](https://www.lazyvim.org/).

Stow links individual files from `packages/` and keeps real config directories.
Profile changes unstow the saved profile and install the selected profile's links.
They do not uninstall apps or remove ordinary user files.

App configs are installed in `${XDG_CONFIG_HOME:-~/.config}`. `XDG_CONFIG_HOME`
must be an absolute path. Shell entry points and executables stay in your home
directory. The config directory is saved with the profile; changing it on a later
run removes the managed links from the saved directory and installs them in the
selected directory. Local files and application data are not moved.

Existing conflicting files are adopted into the selected Stow package with
`--adopt`. Adoption changes the checkout and preserves the local file's contents.
Inspect `git diff` before you commit adopted files, especially shell files shared
between platforms. Use `scripts/stow.sh` to apply the selected packages.

## Shell behavior

- Mac-only paths, plugins, aliases, and functions are guarded by OS/tool checks.
- Human sessions use available terminal tools. Agent and IDE sessions keep a
  plain prompt. Noninteractive shell initialization does not load prompt plugins.
- Atuin records local history. Automatic history sync and its daemon are disabled.
  Setup does not configure an account or copy credentials.
- `c` and `p` use the local Mac, Wayland, or X11 clipboard. Over SSH, `c` uses
  OSC 52, including tmux passthrough. The terminal and multiplexer must permit it.
  `p` over SSH tells you to paste from your local terminal.
- Linux Ghostty and Zed configs use Linux keys. The Mac cmux config is not linked
  to the different Linux GUI app; Linux cmux uses its own defaults.

Keep secrets in `~/.secrets`. Put local overrides in
`${XDG_CONFIG_HOME:-~/.config}/dotfiles/local.zsh`. These files and saved machine
state are not tracked. Optional local tool environment files are loaded only
when present.

Put machine-specific login settings in
`${XDG_CONFIG_HOME:-~/.config}/dotfiles/login.zsh`. This file is loaded by Zsh
login shells and is also outside the checkout. It is optional; fresh machines do
not need this file to start Zsh. Homebrew initialization is shared
by the setup scripts and Zsh, with support for both Mac architectures.

## Updates

```bash
bash scripts/update.sh
bash scripts/update.sh --config-only
```

Debian/Ubuntu and Fedora refresh metadata and install/upgrade the selected
packages and dependencies. Native packages installed from release downloads are
resolved again so they can update too. Arch runs a **full system upgrade** before
selected package installation and rebuilds selected AUR packages. Arch does not
support partial upgrades. Mac retains `brew update`, `brew upgrade`, and
`brew cleanup`. Config links are refreshed after package operations.

The update command does not pull Git changes. Pull this repository separately.
To recover adopted contents, use Git to inspect or restore the affected package
file, then run `scripts/stow.sh` again. If a command fails before completion,
resolve its error and rerun it; profile state is saved only after linking succeeds.

## Offline checks

With Python 3, GNU Stow, and Zsh installed:

```bash
python3 -m unittest discover -s tests -v
```

The checks use a temporary checkout and home directory. They cover profile
linking, profile switching, adoption, missing tools, package failure handling, clipboard
output, and native package selection. Package-manager calls are mocked; these
checks do not install system packages or prove distro-specific availability.
