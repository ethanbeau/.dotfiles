# Use the local OS clipboard on desktops and OSC 52 over SSH.
unalias c p 2>/dev/null || true

c() {
  if [[ "$OSTYPE" == darwin* ]] && (( $+commands[pbcopy] )) && [[ -z "$SSH_CONNECTION$SSH_TTY" ]]; then
    command pbcopy "$@"
  elif [[ -z "$SSH_CONNECTION$SSH_TTY" && -n "$WAYLAND_DISPLAY" ]] && (( $+commands[wl-copy] )); then
    command wl-copy "$@"
  elif [[ -z "$SSH_CONNECTION$SSH_TTY" && -n "$DISPLAY" ]] && (( $+commands[xclip] )); then
    command xclip -selection clipboard "$@"
  elif [[ "$TERM" != dumb && -t 1 ]] && (( $+commands[base64] )); then
    local encoded
    if (( $# )); then
      encoded="$(printf '%s' "$*" | command base64 | tr -d '\r\n')"
    else
      encoded="$(command base64 | tr -d '\r\n')"
    fi
    if [[ -n "$TMUX" ]]; then
      printf '\033Ptmux;\033\033]52;c;%s\007\033\\' "$encoded"
    else
      printf '\033]52;c;%s\007' "$encoded"
    fi
  else
    print -u2 'Copy needs a desktop clipboard or a terminal with OSC 52 support.'
    return 1
  fi
}

p() {
  if [[ -n "$SSH_CONNECTION$SSH_TTY" ]]; then
    print -u2 'Paste from the local terminal. Remote clipboard reads are not configured.'
    return 1
  elif [[ "$OSTYPE" == darwin* ]] && (( $+commands[pbpaste] )); then
    command pbpaste "$@"
  elif [[ -n "$WAYLAND_DISPLAY" ]] && (( $+commands[wl-paste] )); then
    command wl-paste "$@"
  elif [[ -n "$DISPLAY" ]] && (( $+commands[xclip] )); then
    command xclip -selection clipboard -o "$@"
  else
    print -u2 'No local clipboard backend is available.'
    return 1
  fi
}
