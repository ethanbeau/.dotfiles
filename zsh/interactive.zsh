# =============================================================================
# 4. ENVIRONMENT CHECK (Agent/IDE vs Human)
# =============================================================================
if [[ "$TERM" == "dumb" || "$TERM_PROGRAM" == "vscode" || -n "$VSCODE_INJECTION" || -n "$CLAUDE_CLI" || -n "$GITHUB_COPILOT_CLI" || -n "$GEMINI_CLI" || -n "$CODEX_CLI" || -n "$OPENCODE_CLI" || -n "$PI_CLI" ]]; then

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
