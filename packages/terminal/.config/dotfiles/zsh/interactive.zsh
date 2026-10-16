# Keep agent and IDE prompts plain.
if [[ ! -t 0 || ! -t 1 || ! -o zle || "$TERM" == dumb ||
      "$TERM_PROGRAM" == vscode || -n "$VSCODE_INJECTION" ||
      -n "$CLAUDE_CLI" || -n "$GITHUB_COPILOT_CLI" || -n "$GEMINI_CLI" ||
      -n "$CODEX_CLI" || -n "$OPENCODE_CLI" || -n "$PI_CLI" ]]; then
  PROMPT='%~ %# '
  RPROMPT=''
  return 0
fi

PROMPT='%n@%m:%~ %# '
(( $+commands[starship] )) && eval "$(starship init zsh)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"

# Neovim and previews use wrappers for Linux fd/bat package names when needed.
if (( DOTFILES_HAS_FD )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
fi
if (( $+commands[eza] && DOTFILES_HAS_BAT )); then
  export FZF_CTRL_T_OPTS="--preview 'if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat --style=numbers --color=always --line-range :500 {}; fi' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
fi

fpath=("$DOTFILES_ZSH_DIR/functions" $fpath)
for completion_dir in "${HOMEBREW_PREFIX}/share/zsh-completions" /usr/share/zsh-completions /usr/share/zsh/vendor-completions /usr/share/zsh/site-functions; do
  [[ -d "$completion_dir" ]] && fpath=("$completion_dir" $fpath)
done
unset completion_dir

autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

if (( $+commands[fzf] )); then
  if fzf_init="$(fzf --zsh 2>/dev/null)"; then
    eval "$fzf_init"
  else
    for fzf_bindings in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/shell/key-bindings.zsh /usr/share/fzf/key-bindings.zsh; do
      if [[ -r "$fzf_bindings" ]]; then source "$fzf_bindings"; break; fi
    done
    unset fzf_bindings
  fi
  unset fzf_init
fi
(( $+commands[atuin] )) && eval "$(atuin init zsh)"

zstyle ':completion:*' menu select false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}No matches for:%f %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

_dotfiles_plugin() {
  local name="$1" file
  for file in \
    "${HOMEBREW_PREFIX}/share/$name/$name.zsh" \
    "${HOMEBREW_PREFIX}/opt/$name/share/$name/$name.zsh" \
    "/usr/share/$name/$name.zsh" \
    "/usr/share/$name/$name.plugin.zsh" \
    "/usr/share/zsh/plugins/$name/$name.zsh" \
    "/usr/share/zsh/plugins/$name/$name.plugin.zsh" \
    "/usr/share/zsh/site-functions/$name.zsh"; do
    if [[ -r "$file" ]]; then source "$file"; return 0; fi
  done
  return 0
}
(( $+commands[fzf] )) && _dotfiles_plugin fzf-tab
_dotfiles_plugin zsh-autosuggestions
if (( $+widgets[autosuggest-accept] )); then
  bindkey '^ ' autosuggest-accept
  bindkey '^@' autosuggest-accept
fi

if (( $+commands[eza] )); then
  alias ls='eza -a --icons --group-directories-first --git'
  alias ll='eza -l --icons --group-directories-first --git --header'
  alias la='eza -la --icons --group-directories-first --git --header'
  alias lx='eza -lah --icons --group-directories-first --git --header'
  alias lt='eza --tree --level=2 --icons'
  alias lS='eza -1'
fi
if (( DOTFILES_HAS_BAT )); then alias cat=bat; alias CAT='\cat'; fi
if (( $+commands[fzf] && $+commands[rg] )); then
  alias ff="fzf --ansi --disabled --prompt 'Grep> ' --bind 'start:reload(rg --color=always --line-number --no-heading --smart-case \"\" || true)' --bind 'change:reload(rg --color=always --line-number --no-heading --smart-case {q} || true)'"
fi

# Syntax highlighting must load after other widgets.
_dotfiles_plugin zsh-syntax-highlighting
unfunction _dotfiles_plugin
