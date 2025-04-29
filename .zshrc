plugins=(git aliases history z tmux zsh-autosuggestions zsh-syntax-highlighting archlinux docker-compose)

export TERM=xterm-256color
export TERMINAL=/usr/bin/kitty

bindkey '^p' autosuggest-accept

alias pm="python main.py"
alias pcd="python /home/sinsenti/dotfiles/.config/scripts/create_python_dir_with_main.py"
alias matrix="cmatrix -b -s -u 3 -C cyan"
alias gbv="git branch --verbose"
alias soliditycopy="python /home/sinsenti/dotfiles/.config/scripts/backup_solidity_project.py"
alias smartcopy="python /home/sinsenti/dotfiles/.config/scripts/backup_code.py"
alias copyall="~/dotfiles/.config/scripts/copy_all.sh"
alias gitpush="~/dotfiles/.config/scripts/git_push.sh"
alias run="~/dotfiles/.config/scripts/run_scripts.sh"
alias TT="~/dotfiles/.config/scripts/toggle_noblur.sh"
alias layout="watch -n 0.5 ~/dotfiles/.config/scripts/switch_keyboard.sh"
alias n="nvim"
alias cl='clear'
alias nz="nvim ~/.zshrc"
alias sz="source ~/.zshrc"
alias e="exit"
alias q="exit"
alias ff='fzf --height 100% --preview "bat -n --color=always --theme=Dracula {}" | { read -r file && nvim "$file"; }'
alias tree='exa --tree --header --icons -a --level=1 --group-directories-first'
alias tree1='exa --tree --header --icons -a --level=1 --group-directories-first'
alias tree2='exa --tree --header --icons -a --level=2 --group-directories-first'
alias tree3='exa --tree --header --icons -a --level=3 --group-directories-first'
alias tree0='exa --tree --header --icons -a'
alias ffg='find_preview'
alias nt='nvim ~/.tmux.conf'



source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory



function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

unsetopt BEEP


find_preview() {
  rg --hidden --line-number --color=always "$1" \
    | fzf --ansi \
          --preview 'echo "\033[1;35mFile: $(echo {} | cut -d: -f1)\033[0m" && bat --style=numbers --color=always --theme=Dracula --line-range :500 $(echo {} | cut -d: -f1) --highlight-line $(echo {} | cut -d: -f2)' \
          --preview-window=right:60%:wrap \
    | while IFS=: read -r file line _; do
        nvim +"$line" "$file"
      done
}

export EDITOR='nvim'

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

source $ZSH/oh-my-zsh.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
echo -ne '\e[5 q'


export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
