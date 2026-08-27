# ==========================================
# 1. Powerlevel10k Instant Prompt (Keep Top!)
# ==========================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==========================================
# 2. Zinit Framework Initialization
# ==========================================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Load theme immediately so prompt draws instantly
zinit ice depth=1; zinit light romkatv/powerlevel10k

# ==========================================
# 3. Blazing Fast Cached Completion Engine
# ==========================================
[[ -d "$HOME/.bun" ]] && fpath=("$HOME/.bun" $fpath)

autoload -Uz compinit
if [[ ! -f "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump" || -n "$(find "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump" -mtime +1)" ]]; then
    compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
else
    compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
fi
zinit cdreplay -q

# ==========================================
# 4. Zinit Turbo Mode: Background Asynchronous Loading
# ==========================================
zinit ice wait"0" lucid
zinit light Aloxaf/fzf-tab

zinit ice wait"0" lucid atload"_zsh_autosuggest_start"
zinit light zsh-users/zsh-autosuggestions

zinit ice wait"0" lucid
zinit light zsh-users/zsh-syntax-highlighting

zinit ice wait"0" lucid; zinit snippet OMZP::command-not-found
zinit ice wait"0" lucid; zinit snippet OMZP::docker-compose

# Clean vi-mode snippet (Without FZF keybinding hijack)
# Clean vi-mode snippet with modern Atuin widget bindings
zinit ice wait"0" lucid atload"bindkey -M viins '^r' atuin-search-viins; bindkey -M vicmd '^r' atuin-search-vicmd"
zinit snippet OMZP::vi-mode
zinit snippet OMZP::git

ZSH_TMUX_AUTOSTART_ONCE=true
ZSH_TMUX_AUTOCONNECT=true
zinit ice wait"0" lucid
zinit snippet OMZP::tmux

if [[ ! -f ~/.zoxide-static.zsh ]]; then
    zoxide init zsh > ~/.zoxide-static.zsh
fi
source ~/.zoxide-static.zsh

zinit ice wait"0" lucid blockf
zinit light carapace-sh/carapace-bin

# ==========================================
# 5. Environment and Global Exports
# ==========================================
export TERM=xterm-256color
export TERMINAL=/usr/bin/kitty
export EDITOR="nvim"
export VISUAL="nvim"
export SYSTEMD_EDITOR="nvim"
export SUDO_EDITOR="nvim"
export OLLAMA_NUM_THREADS=4
export GEMINI_STORAGE_BACKEND=plaintext
export TODO_DIR="$HOME/Documents"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Path Expansions
export BUN_INSTALL="$HOME/.bun"
export PATH="$HOME/.atuin/bin:$BUN_INSTALL/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export YDOTOOL_SOCKET=/tmp/.ydotool_socket

[[ -f ~/.env ]] && source ~/.env

export CARAPACE_BRIDGES='zsh,bash'
zstyle ':completion:*:git:*' group-order 'main commands','alias commands','external commands'
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# ==========================================
# 6. Lazy-Loading Modules & History Configuration
# ==========================================
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}

[ -f ~/.fzf-static.zsh ] && source ~/.fzf-static.zsh

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
HISTDUP=erase
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_ignore_dups
unsetopt BEEP

# Prevent multi-line standard input pastes from polluting history
zshaddhistory() {
  [[ $1 == *"cat <<"* ]] && return 1
  return 0
}

# Preexec hook to track execution context for headless Zenity rerun script
preexec() { printf '%s\n%s\n' "$PWD" "$1" > ~/.cache/last_cmd ; }

# ==========================================
# 7. Dynamic Modular Function Sourcing
# ==========================================
# Automatically loads ~/.config/zsh/functions/atuin.zsh along with all other modules
for config_file (~/.config/zsh/functions/*.zsh); do
  source "$config_file"
done

# ==========================================
# 8. Post-Prompt Theme & Non-Atuin Keybindings
# ==========================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Secondary Fallback: FZF History on Alt+R
bindkey '^[r' fzf-history-widget
bindkey -M viins '^[r' fzf-history-widget
bindkey -M vicmd '^[r' fzf-history-widget

# Zsh Autosuggestion Keybindings
bindkey '^o' autosuggest-execute
bindkey '^p' autosuggest-accept
bindkey -M viins '^o' autosuggest-execute
bindkey -M viins '^p' autosuggest-accept

# Edit command line in Neovim widget
function open_nvim_command_line() {
    export NVIM_FAST_MODE=1
    autoload -Uz edit-command-line
    zle edit-command-line
    unset NVIM_FAST_MODE
}
zle -N open_nvim_command_line
bindkey -M vicmd 'v' open_nvim_command_line

export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
