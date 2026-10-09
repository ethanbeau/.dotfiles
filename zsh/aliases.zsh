alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

alias grep="rg"
alias GREP="\grep"
alias find="fd"
alias FIND="\find"
alias du="dust"
alias DU="\du"

alias c="pbcopy"
alias p="pbpaste"

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

alias v="nvim"
alias vim="nvim"
alias VIM="\vim"
alias mkdir="mkdir -p"
alias python="python3"
alias pip="pip3"
alias uuidgen="uuidgen | tr '[:upper:]' '[:lower:]'"
alias lg="lazygit"
alias brewup="brew update && brew upgrade"
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
