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
  git clone depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Load theme immediately so the prompt draws instantly
zinit ice depth=1; zinit light romkatv/powerlevel10k

# ==========================================
# 3. Blazing Fast Cached Completion Engine
# ==========================================
# Native lazy-loading for Bun completions by leveraging fpath
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

# Explicitly rebinds widgets atload to bring back the ghost text immediately
zinit ice wait"0" lucid atload"_zsh_autosuggest_start"
zinit light zsh-users/zsh-autosuggestions

zinit ice wait"0" lucid
zinit light zsh-users/zsh-syntax-highlighting

# Load Snippets asynchronously
zinit ice wait"0" lucid; zinit snippet OMZP::command-not-found
zinit ice wait"0" lucid; zinit snippet OMZP::docker-compose

# Handle vi-mode keymap initialization asynchronously
zinit ice wait"0" lucid atload"bindkey -M viins '^r' fzf-history-widget; bindkey -M vicmd '^r' fzf-history-widget"
zinit snippet OMZP::vi-mode
zinit snippet OMZP::git

# Optimized OMZP::tmux handling
ZSH_TMUX_AUTOSTART_ONCE=true
ZSH_TMUX_AUTOCONNECT=true
zinit ice wait"0" lucid
zinit snippet OMZP::tmux

# Asynchronously evaluate Zoxide to eliminate subshell fork lag
# Static Zoxide generation to completely eliminate subshell fork lag (0ms startup)
if [[ ! -f ~/.zoxide-static.zsh ]]; then
    zoxide init zsh > ~/.zoxide-static.zsh
fi
source ~/.zoxide-static.zsh

# Asynchronously initialize Carapace 
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

# Path expansions (Inlined Cargo path to completely skip sourcing its env file)
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Run local environments
[[ -f ~/.env ]] && source ~/.env

export CARAPACE_BRIDGES='zsh,bash'
zstyle ':completion:*:git:*' group-order 'main commands','alias commands','external commands'
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# ==========================================
# 6. Lazy-Loading Modules
# ==========================================
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}

# Read compiled FZF layout statically
[ -f ~/.fzf-static.zsh ] && source ~/.fzf-static.zsh

# Keybindings & History
bindkey '^r' fzf-history-widget
bindkey -M viins '^r' fzf-history-widget
bindkey -M vicmd '^r' fzf-history-widget

bindkey '^o' autosuggest-execute
bindkey '^p' autosuggest-accept
bindkey -M viins '^o' autosuggest-execute
bindkey -M viins '^p' autosuggest-accept

function open_nvim_command_line() {
    # Set the fast mode flag globally for this subshell execution
    export NVIM_FAST_MODE=1
    autoload -Uz edit-command-line
    zle edit-command-line
    unset NVIM_FAST_MODE
}
zle -N open_nvim_command_line
bindkey -M vicmd 'v' open_nvim_command_line

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
HISTDUP=erase
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_ignore_dups
unsetopt BEEP

# Don't save 'cat <<' multiline pastes to history
zshaddhistory() {
  [[ $1 == *"cat <<"* ]] && return 1
  return 0
}

# ==========================================
# 7. Dynamic Modular Function Sourcing
# ==========================================
for config_file (~/.config/zsh/functions/*.zsh); do
  source "$config_file"
done

# ==========================================
# 8. Post-Prompt Profile Theme Sourcing
# ==========================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
