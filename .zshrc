# =============================================================================
# CORE ENV & BEHAVIOR CONFIGURATION
# =============================================================================
export XDG_CONFIG_HOME="$HOME/.config"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

# =============================================================================
# ALIASES
# =============================================================================
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
alias ga="git add"
alias gc="git commit -m"
alias gp="git pull"
alias gpo="git push origin"
alias gl="git log --oneline --graph --decorate"
alias gsw="git switch"
alias gd="git diff"
alias grs="git restore"

alias v="nvim"
alias vim="nvim"
alias VIM="\vim"
alias mkdir="mkdir -p"
alias python="python3"
alias pip="pip3"
alias uuidgen="uuidgen | tr '[:upper:]' '[:lower:]'"
alias lg="lazygit"

alias reload="source ~/.zshrc && echo 'Reloaded .zshrc'"

# Agent CLI wrappers to force fallback prompt
alias codex="CODEX_CLI=1 codex"
alias copilot="GITHUB_COPILOT_CLI=1 copilot"
alias gemini="GEMINI_CLI=1 gemini"
alias claude="CLAUDE_CLI=1 claude"

# Coding harness aliases
_agent() {
  local agent=$1 mode=$2
  local tier effort
  local -a args models

  shift 2

  # Optional model selector:
  #
  # 0      Haiku / Luna
  # 1      Sonnet / Terra
  # 2      Opus / Sol
  #
  # 0l     tier 0 + low effort
  # 0m     tier 0 + medium effort
  # 0h     tier 0 + high effort
  # 0xh    tier 0 + xhigh effort
  #
  # No selector:
  # use whatever model/effort the underlying CLI/config selects.

  if (( $# )); then
    case $1 in
      [012])
        tier=$1
        shift
        ;;
      [012]l)
        tier=${1[1]}
        effort=low
        shift
        ;;
      [012]m)
        tier=${1[1]}
        effort=medium
        shift
        ;;
      [012]h)
        tier=${1[1]}
        effort=high
        shift
        ;;
      [012]xh)
        tier=${1[1]}
        effort=xhigh
        shift
        ;;
      [[:digit:]][[:alpha:]]*)
        print -u2 "Invalid selector: $1"
        print -u2 "Expected: {0|1|2}[l|m|h|xh]"
        return 2
        ;;
    esac
  fi

  case $agent in
    claude)
      args=(claude)
      models=(haiku sonnet opus)

      [[ -n $tier ]] &&
        args+=(--model "${models[$(( tier + 1 ))]}")

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

      [[ -n $effort ]] &&
        args+=(--effort "$effort")

      CLAUDE_CLI=1 command "${args[@]}" "$@"
      ;;

    codex)
      args=(codex)
      models=(gpt-5.6-luna gpt-5.6-terra gpt-5.6-sol)

      [[ -n $tier ]] &&
        args+=(--model "${models[$(( tier + 1 ))]}")

      case $mode in
        default)
          # Preserve Codex's configured approval + sandbox settings.
          ;;
        strict)
          args+=(
            --sandbox read-only
            --ask-for-approval untrusted
          )
          ;;
        auto)
          args+=(
            --sandbox workspace-write
            --ask-for-approval on-request
            -c 'approvals_reviewer="auto_review"'
          )
          ;;
        yolo)
          args+=(--yolo)
          ;;
        *)
          print -u2 "Invalid agent/mode: $agent/$mode"
          return 2
          ;;
      esac

      [[ -n $effort ]] &&
        args+=(-c "model_reasoning_effort=\"$effort\"")

      CODEX_CLI=1 command "${args[@]}" "$@"
      ;;
    *)
      print -u2 "Invalid agent/mode: $agent/$mode"
      return 2
      ;;
  esac
}

# Claude
cc()       { _agent claude default "$@" }
ccstrict() { _agent claude strict  "$@" }
ccauto()   { _agent claude auto    "$@" }
ccyolo()   { _agent claude yolo    "$@" }

# Codex
cx()       { _agent codex default "$@" }
cxstrict() { _agent codex strict  "$@" }
cxauto()   { _agent codex auto    "$@" }
cxyolo()   { _agent codex yolo    "$@" }

# =============================================================================
# 4. ENVIRONMENT CHECK (Agent/IDE vs Human)
# =============================================================================
if [[ "$TERM" == "dumb" || "$TERM_PROGRAM" == "vscode" || -n "$VSCODE_INJECTION" || -n "$CLAUDE_CLI" || -n "$GITHUB_COPILOT_CLI" || -n "$GEMINI_CLI" || -n "$CODEX_CLI" ]]; then

  # --- AGENT / IDE MODE ---
  # Keep it as plain and POSIX-compliant as possible
  PROMPT='%~ %# '
  RPROMPT=''

else

  # --- INTERACTIVE HUMAN MODE ---
  # Put all your visual, interactive, and heavy tools here

  # Prompt
  eval "$(starship init zsh)"

  # FZF Configuration
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  export FZF_CTRL_T_OPTS="
    --preview 'if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat --style=numbers --color=always --line-range :500 {}; fi'
    --bind 'ctrl-/:change-preview-window(down|hidden|)'"

  # Interactive Tool Initialization
  eval "$(zoxide init zsh --cmd cd)"
  eval "$(fzf --zsh)"
  eval "$(atuin init zsh)"

  # Visual Aliases
  alias ls="eza -a --icons --group-directories-first --git"
  alias ll="eza -l --icons --group-directories-first --git --header"
  alias la="eza -la --icons --group-directories-first --git --header"
  alias lx="eza -lah --icons --group-directories-first --git --header"
  alias lt="eza --tree --level=2 --icons"
  alias lS="eza -1"

  alias cat="bat"
  alias CAT="\cat"

  alias ff="fzf --ansi --disabled --prompt 'Grep> ' \
    --bind 'start:reload(rg --color=always --line-number --no-heading --smart-case \"\" || true)' \
    --bind 'change:reload(rg --color=always --line-number --no-heading --smart-case {q} || true)'"

  # Sourcing Scripts & Plugins
  fpath=($HOMEBREW_PREFIX/share/zsh-completions $fpath)

  autoload -Uz compinit
  if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
  else
    compinit -C
  fi

  # fzf-tab
  zstyle ':completion:*' menu select false
  source "$HOMEBREW_PREFIX/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"

  # Richer completion formatting
  zstyle ':completion:*:descriptions' format '[%d]'
  zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
  zstyle ':completion:*:warnings' format ' %F{red}No matches for:%f %d'
  zstyle ':completion:*' group-name ''
  zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

  # Zsh Autosuggestions
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  bindkey '^ ' autosuggest-accept
  bindkey '^@' autosuggest-accept

  # Syntax Highlighting (Must be at the end of the interactive block)
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

fi

# =============================================================================
# FUNCTIONS
# =============================================================================
mkcd() { mkdir -p "$1" && cd "$1"; }

function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;; *.tar.gz) tar xzf "$1" ;;
      *.bz2) bunzip2 "$1"     ;; *.rar) unrar x "$1"    ;;
      *.gz) gunzip "$1"       ;; *.tar) tar xf "$1"     ;;
      *.tbz2) tar xjf "$1"    ;; *.tgz) tar xzf "$1"    ;;
      *.zip) unzip "$1"       ;; *.Z) uncompress "$1"   ;;
      *.7z) 7z x "$1"         ;; *) echo "Error"        ;;
    esac
  fi
}

fif() {
  if [ ! "$#" -gt 0 ]; then echo "Need a string!"; return 1; fi
  rg --color=always --line-number --no-heading --smart-case "${*:-}" |
    fzf --ansi \
        --color "hl:-1:underline,hl+:-1:underline:reverse" \
        --delimiter : \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --bind 'enter:become(nvim {1} +{2})'
}

kport() {
  local port="$1"
  lsof -tiTCP:"$port" -sTCP:LISTEN | xargs kill -9
}


# ==============================================================================
# LOCAL ENV & SECRETS
# ==============================================================================
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
[ -f ~/.secrets ] && source ~/.secrets


# dcg: warn if hook was silently removed from Claude Code settings
if command -v dcg &>/dev/null && command -v jq &>/dev/null; then
  if [ -f "$HOME/.claude/settings.json" ] &&      ! jq -e '.hooks.PreToolUse[]? | select(.hooks[]?.command | test("dcg\"?$"))'        "$HOME/.claude/settings.json" &>/dev/null; then
    printf '\033[1;33m[dcg] Hook missing from ~/.claude/settings.json — run: dcg install\033[0m\n'
  fi
fi
