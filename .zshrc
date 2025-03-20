plugins=(git aliases history z tmux zsh-autosuggestions zsh-syntax-highlighting archlinux)

export TERM=xterm-256color
export TERMINAL=/usr/bin/alacritty

bindkey '^p' autosuggest-accept
# bindkey '^M' autosuggest-accept
alias ni='nvim ~/.config/i3/config'
alias na='nvim ~/.config/alacritty/alacritty.toml'
alias top='bpytop'


source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory


alias wayon="systemctl --user enable --now waybar.service"
alias wayoff="systemctl --user disable --now waybar.service"
alias nh="nvim ~/.config/hypr/hyprland.conf"
alias matrix="tmatrix -c default -s 50 -f 0.3,0.7 -g 0,45 -G 10,20 --no-fade -t 'OUR LIFE IS THE CREATION OF OUR MIND' -C blue"
alias n="nvim"
alias cl='clear'
alias nz="nvim ~/.zshrc"
alias ns="nvim -S"
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



