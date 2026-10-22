alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

(( $+commands[rg] )) && alias grep="rg"
alias GREP="\grep"
(( DOTFILES_HAS_FD )) && alias find="fd"
alias FIND="\find"
(( $+commands[dust] )) && alias du="dust"
alias DU="\du"

alias gs="git status"
alias gc="git commit -m"
alias gp="git pull"
alias gpo="git push origin"
alias gl="git log --oneline --graph --decorate"
alias gsw="git switch"
alias gd="git diff"
alias grs="git restore"
alias prs="gh pr list"
alias prc="gh pr checkout"
alias lgtm="gh pr review --approve"

alias dk="docker"
alias dkprune="docker image prune -a"
alias dkc="docker compose"
alias dkcl="docker compose logs"
alias dkcb="docker compose build"
alias dkcB="docker compose build --no-cache"
if [[ "$OSTYPE" == darwin* ]]; then
  alias dkstart="orb start"
  alias dkstop="orb stop"
elif [[ "$OSTYPE" == linux* ]]; then
  alias dkstart="sudo systemctl start docker"
  alias dkstop="sudo systemctl stop docker"
fi


if (( $+commands[nvim] )); then
  alias v="nvim"
  alias vim="nvim"
fi
alias VIM="\vim"
alias mkdir="mkdir -p"
(( $+commands[python3] )) && alias python="python3"
(( $+commands[pip3] )) && alias pip="pip3"
alias uuidgen="uuidgen | tr '[:upper:]' '[:lower:]'"
alias lg="lazygit"
alias ld="lazydocker"
sysup() {
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null || { print -u2 'sysup: Homebrew is not installed'; return 127; }
      brew update && brew upgrade
      ;;
    Linux)
      [[ -r /etc/os-release ]] || { print -u2 'sysup: cannot read /etc/os-release'; return 1; }
      source /etc/os-release
      local manager
      case "${ID:-} ${ID_LIKE:-}" in
        *debian*|*ubuntu*) manager=apt ;;
        *fedora*|*rhel*|*centos*) manager=dnf ;;
        *arch*) manager=pacman ;;
        *) print -u2 "sysup: unsupported Linux distribution: ${PRETTY_NAME:-${ID:-unknown}}"; return 1 ;;
      esac
      local -a sudo_cmd=()
      if (( EUID != 0 )); then
        command -v sudo >/dev/null || { print -u2 'sysup: sudo is required'; return 127; }
        sudo_cmd=(sudo)
      fi
      case "$manager" in
        apt) "${sudo_cmd[@]}" apt update && "${sudo_cmd[@]}" apt upgrade ;;
        dnf) "${sudo_cmd[@]}" dnf upgrade --refresh ;;
        pacman) "${sudo_cmd[@]}" pacman -Syu ;;
      esac
      ;;
    *)
      print -u2 "sysup: unsupported operating system: $(uname -s)"
      return 1
      ;;
  esac
}

alias secret="openssl rand -hex 32"

alias reload="source ~/.zshrc && echo 'Reloaded .zshrc'"

# Agent CLI wrappers to force fallback prompt
alias codex="CODEX_CLI=1 codex"
alias copilot="GITHUB_COPILOT_CLI=1 copilot"
alias gemini="GEMINI_CLI=1 gemini"
alias claude="CLAUDE_CLI=1 claude"
alias opencode="OPENCODE_CLI=1 opencode"
alias pi="PI_CLI=1 pi"

# Coding harness aliases
_agent() {
  local agent=$1 mode=$2
  local -a args

  shift 2

  case $agent in
    claude)
      args=(claude)
      case $mode in
        default)
          # Preserve Claude's configured permission mode.
          ;;
        strict)
          args+=(--permission-mode default)
          ;;
        auto)
          args+=(--permission-mode auto)
          ;;
        yolo)
          args+=(--permission-mode bypassPermissions)
          ;;
        *)
          print -u2 "Invalid agent/mode: $agent/$mode"
          return 2
          ;;
      esac
      CLAUDE_CLI=1 command "${args[@]}" "$@"
      ;;
    codex)
      args=(codex)
      case $mode in
        default)
          # Preserve Codex's configured approval and sandbox settings.
          ;;
        strict)
          args+=(--sandbox read-only --ask-for-approval untrusted)
          ;;
        auto)
          args+=(--sandbox workspace-write --ask-for-approval on-request -c 'approvals_reviewer="auto_review"')
          ;;
        yolo)
          args+=(--yolo)
          ;;
        *)
          print -u2 "Invalid agent/mode: $agent/$mode"
          return 2
          ;;
      esac
      CODEX_CLI=1 command "${args[@]}" "$@"
      ;;
    *)
      print -u2 "Invalid agent/mode: $agent/$mode"
      return 2
      ;;
  esac
}

# Claude
cc() { _agent claude default "$@"; }
ccstrict() { _agent claude strict "$@"; }
ccauto() { _agent claude auto "$@"; }
ccyolo() { _agent claude yolo "$@"; }

# Codex
cx() { _agent codex default "$@"; }
cxstrict() { _agent codex strict "$@"; }
cxauto() { _agent codex auto "$@"; }
cxyolo() { _agent codex yolo "$@"; }

# OpenCode (permission behavior is controlled by its config or --agent).
oc() { OPENCODE_CLI=1 command opencode "$@"; }
