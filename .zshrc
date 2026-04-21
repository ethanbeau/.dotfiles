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

alias v="nvim"
alias vim="nvim"
alias VIM="\vim"
alias mkdir="mkdir -p"
alias python="python3"
alias pip="pip3"
alias zmxa="zmx attach"
alias uuidgen="uuidgen | tr '[:upper:]' '[:lower:]'"

alias reload="source ~/.zshrc && echo 'Reloaded .zshrc'"

# Agent CLI wrappers to force fallback prompt
alias codex="CODEX_CLI=1 codex"
alias copilot="GITHUB_COPILOT_CLI=1 copilot"
alias gemini="GEMINI_CLI=1 gemini"
alias claude="CLAUDE_CLI=1 claude"

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
  local port-"$1"
  lsof -tiTCP:"$port" -sTCP:LISTEN | xargs kill -9
}


# ==============================================================================
# LOCAL ENV & SECRETS
# ==============================================================================
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
[ -f ~/.secrets ] && source ~/.secrets
