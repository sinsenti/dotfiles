# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

zinit ice depth=1; zinit light romkatv/powerlevel10k


# zinit light zsh-users/zsh-completions

zinit light Aloxaf/fzf-tab
zinit light zsh-users/zsh-syntax-highlighting

zinit light zsh-users/zsh-autosuggestions

zinit snippet OMZP::git
zinit snippet OMZP::archlinux
zinit snippet OMZP::command-not-found
zinit snippet OMZP::docker-compose
zinit snippet OMZP::vi-mode
# zinit snippet OMZP::tmux
# ZSH_TMUX_CONFIG="$HOME/.config/tmux/tmux.conf"
# plugins=(history tmux)

# load completions for zsh
# autoload -Uz compinit && compinit

# carapace completion
zinit light carapace-sh/carapace-bin
autoload -U compinit && compinit
export CARAPACE_BRIDGES='zsh,bash' # optional
# export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
# zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
zstyle ':completion:*:git:*' group-order 'main commands','alias commands','external commands'
source <(carapace _carapace)
zinit cdreplay -q

# bindkey '\t' end-of-line

bindkey '^p' autosuggest-accept

# ctrl-r became comfortable to search through history
eval "$(fzf --zsh)"

# Comppletion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no

# navigate
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

# zioxide
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'



# opencode generated:
#
# autoload -Uz _zinit
# (( ${+_comps} )) && _comps[zinit]=_zinit


alias gdv='git diff -w "$@" | nvim -R -c "set ft=diff" -c "nmap q :q<CR>" -'
alias z="cd"
alias ls="ls --color"
alias a="tmux"
alias st="sudo systemctl status tor"
alias start="sudo systemctl start tor"
alias rest="sudo systemctl restart tor"
alias stop="sudo systemctl stop tor"
alias nh="cd ~/.config/hypr && nvim"
alias wifil="nmcli device wifi list"
alias dcp="docker compose"
alias create="wl-paste --type text/plain > s.sh && bash s.sh"
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
alias gitpush="bash ~/dotfiles/.config/scripts/git_push.sh"
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



# yazi
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



# history settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space

setopt hist_ignore_all_dups
setopt hist_ignore_dups


# shut up sounds
unsetopt BEEP

# term emulator settings
export TERM=xterm-256color
export TERMINAL=/usr/bin/kitty



export EDITOR="nvim"
export VISUAL="nvim"
export SYSTEMD_EDITOR="nvim"
export SUDO_EDITOR="nvim"









# opencode
export PATH=/home/sinsenti/.opencode/bin:$PATH
source ~/.env



# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

eval "$(zoxide init --cmd cd zsh)"
