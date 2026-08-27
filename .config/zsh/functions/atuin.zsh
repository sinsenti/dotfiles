# ~/.config/zsh/functions/atuin.zsh
# Atuin SQLite history initialization and keybindings

export PATH="$HOME/.atuin/bin:$PATH"
export ATUIN_TMUX_POPUP=true
[[ -f "$HOME/.atuin/bin/env" ]] && . "$HOME/.atuin/bin/env"

if command -v atuin &>/dev/null; then
    # Initialize Atuin without hijacking Up-Arrow prompt navigation
    eval "$(atuin init zsh --disable-up-arrow)"

    # Bind Ctrl+R to Atuin across all keymaps (main, insert, normal)
    bindkey '^r' atuin-search
    bindkey -M main '^r' atuin-search
    bindkey -M viins '^r' atuin-search-viins
    bindkey -M vicmd '^r' atuin-search-vicmd
fi
