#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
STATE_FILE="$STATE_DIR/machine"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
PREVIOUS_CONFIG_HOME="$HOME/.config"
PROFILE=""
PREVIOUS_PROFILE=""
EXTRAS=""
CONFIG_ONLY=0
DRY_RUN=0
ADOPT=0
REPORT=()
PACKAGES=()

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }
report() { REPORT+=("$*"); note "Incomplete: $*" >&2; }

run() {
  if (( DRY_RUN )); then
    printf 'Would run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

usage() {
  cat <<'EOF'
Usage: bash scripts/{setup,stow,update}.sh [options]
  --profile macos|linux-server|linux-desktop
  --extras development,containers,utilities   Replace saved extras; use none to clear
  --config-only                             Do not install or update packages
  --dry-run                                 Show actions without changing files
  --adopt                                   Adopt conflicting files with backups
  --help

Profile and extras are saved per user after a successful run.
Arch package operations include a full system upgrade.
EOF
}

read_state() {
  [[ -f "$STATE_FILE" ]] || return 0
  local key value
  while IFS='=' read -r key value; do
    case "$key" in
      profile) PROFILE="$value" ;;
      extras) EXTRAS="$value" ;;
      config_home) PREVIOUS_CONFIG_HOME="$value" ;;
    esac
  done < "$STATE_FILE"
}

parse_args() {
  while (( $# )); do
    case "$1" in
      --profile|--extras)
        (( $# >= 2 )) || die "$1 needs a value"
        case "$1" in
          --profile) PROFILE="$2" ;;
          --extras) EXTRAS="$2" ;;
        esac
        shift 2 ;;
      --config-only) CONFIG_ONLY=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --adopt) ADOPT=1; shift ;;
      --help|-h) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ "$EXTRAS" == none ]] && EXTRAS=""
  local group
  local -a groups
  IFS=',' read -r -a groups <<< "$EXTRAS"
  for group in "${groups[@]}"; do
    case "$group" in
      development|containers|utilities) ;;
      *) die "Unknown extras group: $group" ;;
    esac
  done
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) PLATFORM=macos; BACKEND=brew ;;
    Linux)
      [[ -r /etc/os-release ]] || die 'Cannot read /etc/os-release'
      # shellcheck source=/dev/null
      source /etc/os-release
      PLATFORM=linux
      case "$ID" in
        debian|ubuntu) BACKEND=apt ;;
        fedora)
          [[ ! -e /run/ostree-booted ]] || die 'Immutable Fedora is not supported'
          BACKEND=dnf ;;
        arch) BACKEND=pacman ;;
        *) die "Unsupported distribution: $ID" ;;
      esac
      ;;
    *) die 'Only macOS, Debian, Ubuntu, Fedora, and Arch are supported' ;;
  esac
}

choose_profile() {
  if [[ -z "$PROFILE" ]]; then
    if [[ "$PLATFORM" == macos ]]; then
      PROFILE=macos
    elif [[ -t 0 ]] && (( ! DRY_RUN )); then
      local choice
      read -r -p 'Linux profile: [1] terminal server [2] existing desktop: ' choice
      case "$choice" in
        1) PROFILE=linux-server ;;
        2) PROFILE=linux-desktop ;;
        *) die 'Choose 1 or 2, or use --profile' ;;
      esac
    else
      die 'First Linux run needs --profile linux-server or --profile linux-desktop'
    fi
  fi
  case "$PLATFORM:$PROFILE" in
    macos:macos|linux:linux-server|linux:linux-desktop) ;;
    *) die "Profile $PROFILE is not valid on $PLATFORM" ;;
  esac
  read -r -a PACKAGES <<< "$(profile_packages "$PROFILE")"
}

profile_packages() {
  case "$1" in
    macos) printf '%s\n' 'terminal desktop macos' ;;
    linux-server) printf '%s\n' 'terminal linux' ;;
    linux-desktop) printf '%s\n' 'terminal linux desktop linux-desktop' ;;
    *) die "Unknown saved profile: $1" ;;
  esac
}

has_extra() { [[ ",$EXTRAS," == *",$1,"* ]]; }

obtain_privilege() {
  SUDO=()
  (( CONFIG_ONLY || DRY_RUN )) && return 0
  [[ "$BACKEND" == brew ]] && return 0
  if (( EUID == 0 )); then return 0; fi
  if command -v sudo >/dev/null && sudo -v; then
    SUDO=(sudo)
  else
    CONFIG_ONLY=1
    report 'No sudo access; using config-only setup'
  fi
}

save_state() {
  (( DRY_RUN )) && return 0
  mkdir -p "$STATE_DIR"
  local state_tmp
  state_tmp="$(mktemp "$STATE_DIR/machine.XXXXXX")"
  printf 'profile=%s\nextras=%s\nconfig_home=%s\n' "$PROFILE" "$EXTRAS" "$CONFIG_HOME" > "$state_tmp"
  chmod 600 "$state_tmp"
  mv "$state_tmp" "$STATE_FILE"
}

validate_config_home() {
  [[ "$CONFIG_HOME" == /* && "$CONFIG_HOME" != *$'\n'* ]] || die 'XDG_CONFIG_HOME must be an absolute path without newlines'
}

stow_packages() {
  local operation="$1" config_home="$2" package
  shift 2
  local -a options=(--no-folding --verbose --ignore='(^|/)\.DS_Store$' --ignore='.*\.bak$' --ignore='.*\.lock$')
  if [[ "$operation" == install ]]; then
    # Older Stow versions reject regular files during restow's unstow phase,
    # before adoption can run. Existing correct links are safe to stow again.
    if (( ADOPT )); then options+=(--adopt --stow); else options+=(--restow); fi
  else
    options+=(--delete)
  fi

  for package in "$@"; do
    prune_stale_package_links "$HOME" "$package" ''
  done
  stow --dir="$DOTFILES_DIR/packages" --target="$HOME" \
    --ignore='^\.config$' "${options[@]}" "$@" || return

  for package in "$@"; do
    [[ -d "$DOTFILES_DIR/packages/$package/.config" ]] || continue
    stow_config_package "$operation" "$config_home" "$package" "${options[@]}" || return
  done
}

# Compare links without resolving a final path that can now be missing.
link_points_to() {
  local target="$1" source="$2" link directory prefix=''
  [[ -L "$target" ]] || return 1
  link="$(readlink "$target")" || return 1
  [[ "$link" == "$source" ]] && return 0
  for directory in "$(dirname "$target")" "$(cd "$(dirname "$target")" && pwd -P)"; do
    prefix=''
    while [[ "$source" != "$directory/"* && "$directory" != / ]]; do
      directory="${directory%/*}"
      [[ -n "$directory" ]] || directory=/
      prefix="../$prefix"
    done
    [[ "$link" == "$prefix${source#"${directory%/}/"}" ]] && return 0
  done
  return 1
}

is_stale_package_link() {
  local target="$1" package="$2" relative="$3" root
  [[ -L "$target" && ! -e "$target" ]] || return 1
  if link_points_to "$target" "$DOTFILES_DIR/packages/$package/$relative"; then
    return 0
  fi
  for root in "$DOTFILES_DIR" "$HOME/.dotfiles"; do
    # Do not claim links into a different existing checkout.
    if [[ -d "$root" && "$(cd "$root" && pwd -P)" != "$DOTFILES_DIR" ]]; then
      continue
    fi
    if link_points_to "$target" "$root/$relative"; then
      return 0
    fi
  done
  return 1
}

prune_stale_package_links() {
  local target_root="$1" package="$2" source_subdir="$3" source_root file relative
  source_root="$DOTFILES_DIR/packages/$package${source_subdir:+/$source_subdir}"
  [[ -d "$source_root" ]] || return 0
  while IFS= read -r -d '' file; do
    relative="${file#"$source_root"/}"
    if is_stale_package_link "$target_root/$relative" "$package" "${source_subdir:+$source_subdir/}$relative"; then
      unlink "$target_root/$relative" || return
    fi
  done < <(find "$source_root" -mindepth 1 \( -type d -o -type f \) ! -name '.DS_Store' ! -name '*.bak' ! -name '*.lock' -print0)
}

stow_config_package() {
  local operation="$1" config_home="$2" package="$3"
  shift 3
  prune_stale_package_links "$config_home" "$package" '.config'
  if [[ "$package" == macos || "$package" == linux-desktop ]]; then
    # The source-side symlink lets Ghostty resolve the same sibling include
    # after following this config's symlink. The desktop package installs it.
    stow --dir="$DOTFILES_DIR/packages/$package" --target="$config_home" \
      --ignore='^ghostty/common\.ghostty$' "$@" .config
  else
    stow --dir="$DOTFILES_DIR/packages/$package" --target="$config_home" "$@" .config
  fi
}

source "$DOTFILES_DIR/scripts/lib/links.sh"

import_mac_settings() {
  local settings="$DOTFILES_DIR/settings/vorssaint-settings.plist"
  [[ "$PROFILE" == macos && -f "$settings" ]] || return 0
  if (( DRY_RUN )); then note 'Would import Vorssaint preferences'; return 0; fi
  plutil -lint "$settings"
  (
    local prefs
    prefs="$(mktemp)"
    trap 'rm -f "$prefs"' EXIT
    plutil -extract settings xml1 -o "$prefs" "$settings"
    defaults import com.vorssaint.utils "$prefs"
  )
}

offer_login_shell() {
  (( DRY_RUN )) && return 0
  [[ -t 0 ]] || return 0
  [[ -f "$STATE_DIR/shell-choice" ]] && return 0
  local shell_path answer
  shell_path="$(command -v zsh)" || return 0
  if [[ "${SHELL:-}" != "$shell_path" ]]; then
    read -r -p "Change your login shell to $shell_path? [y/N] " answer
    if [[ "$answer" == y || "$answer" == Y ]]; then
      if ! grep -Fxq "$shell_path" /etc/shells; then
        report "$shell_path is not in /etc/shells; login shell unchanged"
        return 0
      fi
      if ! chsh -s "$shell_path"; then
        report 'Could not change login shell; rerun chsh manually'
        return 0
      fi
    fi
  fi
  mkdir -p "$STATE_DIR"
  : > "$STATE_DIR/shell-choice"
}

main() {
  local action="$1"
  shift
  read_state
  PREVIOUS_PROFILE="$PROFILE"
  parse_args "$@"
  validate_config_home
  detect_platform
  choose_profile
  note "Profile: $PROFILE; extras: ${EXTRAS:-none}; packages: $BACKEND"
  if [[ "$BACKEND" == brew ]]; then
    source "$DOTFILES_DIR/scripts/lib/brew.sh"
  else
    source "$DOTFILES_DIR/scripts/lib/linux.sh"
  fi
  if [[ "$action" != stow ]]; then
    obtain_privilege
    if (( CONFIG_ONLY )); then check_packages; else manage_packages "$action"; fi
  fi
  link_configs
  if [[ "$action" == setup ]]; then
    import_mac_settings
    offer_login_shell
  fi
  save_state
  if (( ${#REPORT[@]} )); then
    note ''
    note 'Completed with incomplete items:'
    printf '  - %s\n' "${REPORT[@]}"
  else
    note 'Complete.'
  fi
}
