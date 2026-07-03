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
export ZSH_TMUX_CONFIG="$HOME/dotfiles/.config/tmux/tmux.conf"
# ZSH_TMUX_AUTOSTART=true
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
# 6. LAZY-LOADING HEAVY MODULES (The NVM Fix)
# ==========================================
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}

# ==========================================
# 7. Keybindings, Functions, & Aliases
# ==========================================
# Read the compiled FZF layout statically to stop the subshell fork lag
[ -f ~/.fzf-static.zsh ] && source ~/.fzf-static.zsh

# Strict map assignments across standard and vi states
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
    
    # Clean up the flag after Neovim closes
    unset NVIM_FAST_MODE
}
zle -N open_nvim_command_line
bindkey -M vicmd 'v' open_nvim_command_line

# History Layout Configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
HISTDUP=erase
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_ignore_dups
unsetopt BEEP

# --- Aliases List ---
alias zi="zoxide query -i"
alias т="nvim"
alias t='tuxedo'
alias gpm="git push origin main"
alias wifi="bash ~/dotfiles/.config/scripts/check_wifi.sh"
alias gsp="git stash pop"
alias gsd="git stash drop"
alias gsa="git status apply"
alias ga="git status"
alias gw="git worktree"
alias gst='git stash push -u -m '
alias gsl="git stash list"
alias vpnup='sudo systemctl start wg-quick@wginno'
alias vpndown='sudo systemctl stop wg-quick@wginno'
alias vpnstat='sudo systemctl status wg-quick@wginno'
alias d="docker ps"
alias gds='git diff --staged -w "$@" | nvim -R -c "set ft=diff" -c "nmap q :q<CR>" -'
alias dc="docker compose"
alias b="btop"
alias gcm="git commit --message"
alias g="git status"
alias gdv='git diff -w "$@" | nvim -R -c "set ft=diff" -c "nmap q :q<CR>" -'
alias ls="ls --color"
alias a="tmux"
alias st="sudo systemctl status tor"
alias start="sudo systemctl start tor"
alias rest="sudo systemctl restart tor"
alias stop="sudo systemctl stop tor"
alias nh="cd ~/.config/hypr && nvim"
alias wifil="nmcli device wifi list"
alias dcp="docker compose"
alias glsh="git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad)%Creset' --date=short"
alias zipsrc="zip -r pardaev.zip src"
alias gs="git status"
alias dps="docker ps"
alias dpsa="docker ps -a"
alias mlvenv="source ~/git/ml/.venv/bin/activate"
alias gclone="bash ~/dotfiles/.config/scripts/gclone.sh"
alias gmnoff="git merge --no-ff"
alias jrun="bash ~/dotfiles/.config/scripts/run_all_java_files.sh"
alias grdl="./gradlew clean build; ./gradlew bootRun"
alias crp="bash ~/dotfiles/.config/scripts/create-file-and-paste.sh"
alias matrix="cmatrix -b -s -u 3 -C cyan"
alias gbv="git branch --verbose"
alias smartcopy="python ~/dotfiles/.config/scripts/backup_code.py"
alias copyall="bash ~/dotfiles/.config/scripts/copy_all.sh"
alias n="nvim"
alias c="clear"
alias nz="nvim ~/.zshrc"
alias sz="source ~/.zshrc"
alias e="exit"
alias q="exit"
alias ff='fzf --height 100% --preview "bat -n --color=always --theme=Dracula {}" | { read -r file && nvim "$file"; }'
alias tree='exa --tree --header --icons -a --level=1 --group-directories-first'
alias l='exa --tree --header --icons -a --level=1 --group-directories-first'
alias tree1='exa --tree --header --icons -a --level=1 --group-directories-first'
alias tree2='exa --tree --header --icons -a --level=2 --group-directories-first'
alias tree3='exa --tree --header --icons -a --level=3 --group-directories-first'
alias tree0='exa --tree --header --icons -a'
alias ffg='find_preview'
alias nt='nvim ~/.tmux.conf'

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

find_preview() {
  rg --hidden --line-number --color=always "$1" \
    | fzf --ansi \
          --preview 'echo "\033[1;35mFile: $(echo {} | cut -d: -f1)\033[0m" && bat --style=numbers --color=always --theme=Dracula --line-range :500 $(echo {} | cut -d: -f1) --highlight-line $(echo {} | cut -d: -f2)' \
          --preview-window=right:60%:wrap \
    | while IFS=: read -r file line _; do
        nvim +"$line" "$file"
      done
}

# ==========================================
# 8. Post-Prompt Profile Theme Sourcing
# ==========================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
