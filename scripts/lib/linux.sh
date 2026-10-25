#!/usr/bin/env bash

selected_rows() {
  local group tool apt dnf pacman apt_source dnf_source aur package fallback
  while IFS='|' read -r group tool apt dnf pacman apt_source dnf_source aur; do
    [[ -z "$group" || "$group" == \#* ]] && continue
    case "$group" in
      terminal) ;;
      desktop) [[ "$PROFILE" == linux-desktop ]] || continue ;;
      *) has_extra "$group" || continue ;;
    esac
    # Docker Desktop needs a local graphical session. Do not install it on servers.
    if [[ "$group" == containers && "$PROFILE" == linux-server ]]; then
      continue
    fi
    case "$BACKEND" in
      apt) package="$apt"; fallback="$apt_source" ;;
      dnf) package="$dnf"; fallback="$dnf_source" ;;
      pacman)
        package="$pacman"; fallback="$aur"
        [[ "$fallback" != - ]] || fallback="$package"
        ;;
    esac
    printf '%s|%s|%s\n' "$tool" "$package" "$fallback"
  done < "$DOTFILES_DIR/manifests/linux.psv"
}

package_installed() {
  case "$BACKEND" in
    apt) [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == 'install ok installed' ]] ;;
    dnf) rpm -q "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Q "$1" >/dev/null 2>&1 ;;
  esac
}

package_available() {
  case "$BACKEND" in
    apt) apt-cache policy "$1" 2>/dev/null | grep -Eq 'Candidate: [^ (]' ;;
    dnf) dnf -q repoquery --available --queryformat '%{name}' "$1" 2>/dev/null | grep -Fxq "$1" ;;
    pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
  esac
}

native_install() {
  case "$BACKEND" in
    apt) run "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    dnf) run "${SUDO[@]}" dnf install -y "$@" ;;
    pacman) run "${SUDO[@]}" pacman -S --needed --noconfirm "$@" ;;
  esac
}

check_packages() {
  local tool package fallback
  while IFS='|' read -r tool package fallback; do
    if ! package_installed "$package" && { [[ "$BACKEND" != pacman || "$fallback" == - ]] || ! package_installed "$fallback"; }; then
      report "$tool: package $package is not installed (config-only mode)"
    fi
  done < <(selected_rows)
}

manage_packages() {
  local action="$1" tool package fallback
  local -a native=() missing=()
  if (( DRY_RUN )); then
    note 'Would refresh package metadata (Arch also performs a full system upgrade)'
    while IFS='|' read -r tool package fallback; do
      note "Would select $tool: $package; fallback: $fallback"
    done < <(selected_rows)
    return 0
  fi
  case "$BACKEND" in
    apt) "${SUDO[@]}" apt-get update ;;
    dnf) "${SUDO[@]}" dnf makecache --refresh ;;
    pacman) "${SUDO[@]}" pacman -Syu --noconfirm ;;
  esac
  while IFS='|' read -r tool package fallback; do
    if package_available "$package"; then
      if [[ " ${native[*]} " != *" $package "* ]]; then native+=("$package"); fi
    elif package_installed "$package" && [[ "$action" == setup ]]; then
      note "$tool: installed, but no repository candidate"
    else
      missing+=("$tool|$package|$fallback")
    fi
  done < <(selected_rows)
  # Install repository packages first so optional source handlers have their tools.
  # A failure for one package must not prevent installation of Stow or Zsh.
  for package in "${native[@]}"; do
    if ! native_install "$package"; then report "$package: native package install/upgrade failed"; fi
  done
  for tool in "${missing[@]}"; do
    IFS='|' read -r tool package fallback <<< "$tool"
    if [[ "$BACKEND" == pacman ]]; then
      [[ "$fallback" != - ]] || fallback="$package"
      if ! install_aur "$fallback"; then report "$tool: AUR install/upgrade failed ($fallback)"; fi
    elif [[ "$fallback" == - ]]; then
      report "$tool: $package is unavailable in configured repositories"
    elif ! install_fallback "$fallback" "$package"; then
      report "$tool: source $fallback is unavailable or installation failed"
    fi
  done
  if [[ "$PROFILE" == linux-server ]] && has_extra containers; then
    report 'Docker Desktop needs a GUI; the containers group was skipped on this server'
  fi
  if [[ "$PROFILE" == linux-desktop ]] && command -v fc-cache >/dev/null; then fc-cache -f; fi
}

install_aur() {
  local package="$1"
  (( EUID != 0 )) || { note "AUR $package must be built as a regular user" >&2; return 1; }
  ensure_paru || return 1
  paru -S --needed --noconfirm -- "$package"
}

ensure_paru() {
  command -v paru >/dev/null && return 0
  if package_available paru; then
    native_install paru || return 1
    command -v paru >/dev/null
    return
  fi
  local checkout
  command -v git >/dev/null || return 1
  native_install base-devel git || return 1
  checkout="$(mktemp -d)" || return 1
  (
    trap 'rm -rf "$checkout"' EXIT
    git clone --depth=1 https://aur.archlinux.org/paru.git "$checkout/source" || exit 1
    cd "$checkout/source" || exit 1
    makepkg --syncdeps --install --needed --noconfirm
  ) || return 1
  command -v paru >/dev/null
}

install_copr() {
  local repo="$1" package="$2"
  native_install dnf-plugins-core || return 1
  "${SUDO[@]}" dnf copr enable -y "$repo" || return 1
  native_install "$package"
}

install_helium_apt() {
  command -v curl >/dev/null && command -v gpg >/dev/null || return 1
  local tmp
  tmp="$(mktemp -d)" || return 1
  (
    trap 'rm -rf "$tmp"' EXIT
    curl -fL --retry 2 -o "$tmp/key.asc" https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc || exit 1
    gpg --batch --dearmor -o "$tmp/helium.gpg" "$tmp/key.asc" || exit 1
    "${SUDO[@]}" install -m 644 "$tmp/helium.gpg" /usr/share/keyrings/dotfiles-helium.gpg || exit 1
    printf '%s\n' 'deb [signed-by=/usr/share/keyrings/dotfiles-helium.gpg] https://pkg.helium.computer/deb stable main' > "$tmp/helium.list"
    "${SUDO[@]}" install -m 644 "$tmp/helium.list" /etc/apt/sources.list.d/dotfiles-helium.list || exit 1
    "${SUDO[@]}" apt-get update || exit 1
    native_install helium-bin
  )
}

install_release() {
  local source="$1" tmp extension
  command -v python3 >/dev/null || { note 'python3 is needed to resolve native vendor packages' >&2; return 1; }
  tmp="$(mktemp -d)" || return 1
  case "$BACKEND" in apt) extension=deb ;; dnf) extension=rpm ;; esac
  (
    trap 'rm -rf "$tmp"' EXIT
    python3 "$DOTFILES_DIR/scripts/native-release.py" "$source" "$extension" "$tmp/package.$extension" || exit 1
    native_install "$tmp/package.$extension"
  )
}

install_docker_desktop() {
  # The vendor package depends on Docker CLI packages in Docker's repository.
  [[ "$(uname -m)" == x86_64 ]] || return 1
  command -v curl >/dev/null || return 1
  if [[ "$BACKEND" == apt ]]; then
    command -v gpg >/dev/null || return 1
    local tmp
    tmp="$(mktemp -d)" || return 1
    (
      trap 'rm -rf "$tmp"' EXIT
      curl -fL --retry 2 -o "$tmp/key.asc" "https://download.docker.com/linux/$ID/gpg" || exit 1
      gpg --batch --dearmor -o "$tmp/docker.gpg" "$tmp/key.asc" || exit 1
      "${SUDO[@]}" install -m 644 "$tmp/docker.gpg" /usr/share/keyrings/dotfiles-docker.gpg || exit 1
      printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/dotfiles-docker.gpg] https://download.docker.com/linux/%s %s stable\n' "$ID" "$VERSION_CODENAME" > "$tmp/docker.list"
      "${SUDO[@]}" install -m 644 "$tmp/docker.list" /etc/apt/sources.list.d/dotfiles-docker.list || exit 1
      "${SUDO[@]}" apt-get update || exit 1
      install_release docker-desktop
    )
  else
    "${SUDO[@]}" curl -fL --retry 2 -o /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/fedora/docker-ce.repo || return 1
    install_release docker-desktop
  fi
}

install_fallback() {
  case "$1" in
    copr:*) install_copr "${1#copr:}" "$2" ;;
    helium-apt) install_helium_apt ;;
    ghostty-deb|cmux-deb|bruno-release) install_release "$1" ;;
    docker-desktop) install_docker_desktop ;;
    *) return 1 ;;
  esac
}
