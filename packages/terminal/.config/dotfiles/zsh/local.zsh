# Optional local environments and secrets.
if [[ -r "$HOME/.local/bin/env" ]]; then source "$HOME/.local/bin/env"; fi
if [[ -r "$HOME/.secrets" ]]; then source "$HOME/.secrets"; fi
if [[ -r "$XDG_CONFIG_HOME/vite-plus/env" ]]; then source "$XDG_CONFIG_HOME/vite-plus/env"; fi
