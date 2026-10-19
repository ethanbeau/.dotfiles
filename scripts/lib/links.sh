#!/usr/bin/env bash

# Keep the target/source pairs for both profiles. Directories precede children.
collect_link_targets() {
  local config_home="$1" package source relative target
  shift
  for package in "$@"; do
    while IFS= read -r -d '' source; do
      relative="${source#"$DOTFILES_DIR/packages/$package/"}"
      case "$relative" in
        .config) target="$config_home" ;;
        .config/*)
          target="$config_home/${relative#.config/}"
          if [[ "$relative" == .config/ghostty/common.ghostty && "$package" != desktop ]]; then continue; fi
          ;;
        *) target="$HOME/$relative" ;;
      esac
      LINK_TARGETS+=("$target")
      LINK_SOURCES+=("$source")
      LINK_PACKAGES+=("$package")
    done < <(find "$DOTFILES_DIR/packages/$package" -mindepth 1 \
      \( -name '.DS_Store' -o -name '*.bak' -o -name '*.lock' \) -prune -o -print0)
  done
}

previous_link() {
  local target="$1" i
  for ((i = NEW_TARGET_COUNT; i < ${#LINK_TARGETS[@]}; i++)); do
    if [[ "$target" == "${LINK_TARGETS[i]}" ]] && link_points_to "$target" "${LINK_SOURCES[i]}"; then return 0; fi
  done
  return 1
}

preflight_links() {
  local i source target relative parent boundary failed=0
  for ((i = 0; i < NEW_TARGET_COUNT; i++)); do
    source="${LINK_SOURCES[i]}"
    target="${LINK_TARGETS[i]}"
    relative="${source#"$DOTFILES_DIR/packages/${LINK_PACKAGES[i]}/"}"
    # CONFIG_HOME is initialized by common.sh; config_home is a different local.
    # shellcheck disable=SC2153
    case "$relative" in .config | .config/*) boundary="$CONFIG_HOME" ;; *) boundary="$HOME" ;; esac
    # Reject symlinked parents before inspecting or adopting their children.
    parent="${target%/*}"
    if [[ "$target" == "$boundary" ]]; then parent=''; fi
    while [[ "$parent" != "$boundary" && "$parent" != / && -n "$parent" ]]; do
      if [[ -L "$parent" && ! -d "$parent" ]]; then break; fi
      if [[ -L "$parent" ]]; then
        printf 'Conflict: parent directory is a symlink: %s\n' "$parent" >&2
        failed=1
        break
      elif [[ -e "$parent" && ! -d "$parent" ]]; then
        printf 'Conflict: parent is not a directory: %s\n' "$parent" >&2
        failed=1
        break
      fi
      parent="${parent%/*}"
    done
    if [[ -L "$target" ]]; then
      if is_stale_package_link "$target" "${LINK_PACKAGES[i]}" "$relative"; then
        continue
      elif [[ ! -d "$source" ]] && { link_points_to "$target" "$source" || previous_link "$target"; }; then
        continue
      fi
      printf 'Conflict: target is a symlink: %s -> %s\n' "$target" "$(readlink "$target")" >&2
      failed=1
    elif [[ -e "$target" ]]; then
      if [[ -d "$source" && -d "$target" ]]; then continue; fi
      if [[ ! -d "$source" && -f "$target" ]] && ((ADOPT)); then continue; fi
      printf 'Conflict: %s (use --adopt for regular files)\n' "$target" >&2
      failed=1
    fi
  done
  ((failed == 0))
}

# Snapshot only managed paths. Never copy application data or whole directories.
snapshot_links() {
  local i target source
  mkdir -p "$LINK_BACKUP/targets" "$LINK_BACKUP/sources"
  : >"$LINK_BACKUP/paths.tsv"
  for ((i = 0; i < ${#LINK_TARGETS[@]}; i++)); do
    target="${LINK_TARGETS[i]}"
    source="${LINK_SOURCES[i]}"
    printf '%s\t%s\t%s\n' "$i" "$target" "$source" >>"$LINK_BACKUP/paths.tsv"
    if [[ -L "$target" || -f "$target" ]]; then
      cp -pP "$target" "$LINK_BACKUP/targets/$i"
      LINK_KINDS+=(file)
    elif [[ -d "$target" ]]; then
      LINK_KINDS+=(directory)
    else
      LINK_KINDS+=(missing)
    fi
    if ((ADOPT && i < NEW_TARGET_COUNT)) && [[ -f "$target" && ! -L "$target" && ! -d "$source" ]]; then
      cp -pP "$source" "$LINK_BACKUP/sources/$i"
    fi
  done
}

restore_links() {
  local i target failed=0
  for ((i = ${#LINK_TARGETS[@]} - 1; i >= 0; i--)); do
    target="${LINK_TARGETS[i]}"
    case "${LINK_KINDS[i]}" in
      directory)
        mkdir -p "$target" || failed=1
        ;;
      file)
        mkdir -p "${target%/*}" || failed=1
        if [[ -L "$target" || -f "$target" ]]; then rm -f "$target" || failed=1; fi
        if [[ -d "$target" ]]; then rmdir "$target" || failed=1; fi
        cp -pP "$LINK_BACKUP/targets/$i" "$target" || failed=1
        ;;
      missing)
        if [[ -L "$target" ]]; then
          unlink "$target" || failed=1
        elif [[ -d "$target" ]]; then
          rmdir "$target" 2>/dev/null || true
        fi
        ;;
    esac
    if [[ -e "$LINK_BACKUP/sources/$i" || -L "$LINK_BACKUP/sources/$i" ]]; then
      cp -pP "$LINK_BACKUP/sources/$i" "${LINK_SOURCES[i]}" || failed=1
    fi
  done
  ((failed == 0))
}

finish_link_transaction() {
  local result="$1"
  trap - EXIT HUP INT TERM
  if ((! complete && snapshot_ready)); then
    note 'Linking failed; restoring previous files and links.' >&2
    if ! restore_links; then
      note "Recovery failed. Backups: $LINK_BACKUP" >&2
      exit 1
    fi
  fi
  if ((! ADOPT)); then rm -rf "$LINK_BACKUP"; fi
  exit "$result"
}

link_configs() (
  set -e
  validate_config_home
  # Subshell variables remain available to EXIT traps after a function returns.
  LINK_TARGETS=() LINK_SOURCES=() LINK_PACKAGES=() LINK_KINDS=() previous_packages=()
  complete=0 snapshot_ready=0
  collect_link_targets "$CONFIG_HOME" "${PACKAGES[@]}"
  NEW_TARGET_COUNT=${#LINK_TARGETS[@]}
  if [[ -n "$PREVIOUS_PROFILE" ]]; then
    read -r -a previous_packages <<<"$(profile_packages "$PREVIOUS_PROFILE")"
    collect_link_targets "$PREVIOUS_CONFIG_HOME" "${previous_packages[@]}"
  fi
  preflight_links || die 'Link conflicts found; no links were changed.'
  if ((DRY_RUN)); then
    note "Would link Stow packages: ${PACKAGES[*]}"
    if ((ADOPT)); then note 'Would back up and adopt conflicting regular files'; fi
    note "Config directory: $CONFIG_HOME"
    return 0
  fi
  command -v stow >/dev/null || die 'GNU Stow is required to link configs. Install it, then rerun setup.'
  if ((ADOPT)); then
    mkdir -p "$STATE_DIR/backups"
    LINK_BACKUP="$(mktemp -d "$STATE_DIR/backups/stow.XXXXXX")"
    note "Adoption backups: $LINK_BACKUP (see paths.tsv)"
  else
    LINK_BACKUP="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-stow.XXXXXX")"
  fi
  trap 'finish_link_transaction "$?"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' HUP TERM
  snapshot_links
  snapshot_ready=1
  if [[ -n "$PREVIOUS_PROFILE" && ("$PREVIOUS_PROFILE" != "$PROFILE" || "$PREVIOUS_CONFIG_HOME" != "$CONFIG_HOME") ]]; then
    stow_packages delete "$PREVIOUS_CONFIG_HOME" "${previous_packages[@]}"
  fi
  mkdir -p "$CONFIG_HOME"
  stow_packages install "$CONFIG_HOME" "${PACKAGES[@]}"
  complete=1
)
