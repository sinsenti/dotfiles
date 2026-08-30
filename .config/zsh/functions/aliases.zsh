alias m="bash ~/dotfiles/.config/scripts/focus-diff-monitor.sh"
alias tc='tmux new-window -c "#{pane_current_path}"'
alias tk="tmux kill-pane"
alias tn="tmux next-window"
alias paste_image='wl-paste > "image_$(date +'%Y-%m-%d_%H-%M-%S').png'
alias jv="wl-paste | jq . | nvim -c 'set ft=json' - && rm Untitled"
alias db="python ~/dotfiles/.config/scripts/db.py"
alias t="tuicr"
alias uvp="uv run python"
alias localhost="google-chrome http://localhost:5173 &>/dev/null &"
alias .env='$EDITOR .env'
alias python="python3"
alias lab="cd ~/git/project/a1labs"
alias obs="cd ~/git/obsidian/"

alias zi='cd "$(zoxide query -i)"'
alias т="nvim"
alias gcaq="git commit --amend --no-edit"
alias gpm="git push origin main"
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
alias st="systemctl --user status voxtype"
alias start="sudo systemctl start tor"
alias rest="systemctl --user restart voxtype"
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
alias c="clear"
alias nz="nvim ~/.zshrc"
alias sz="source ~/.zshrc"
alias e="exit"
alias q="exit"
alias ff='fzf --layout=reverse --height 100% --preview "bat -n --color=always --theme=Dracula {}" | { read -r file && nvim "$file"; }'
alias tree='exa --tree --header --icons -a --level=1 --group-directories-first'
alias l='exa --tree --header --icons -a --level=1 --group-directories-first'
alias tree1='exa --tree --header --icons -a --level=1 --group-directories-first'
alias tree2='exa --tree --header --icons -a --level=2 --group-directories-first'
alias tree3='exa --tree --header --icons -a --level=3 --group-directories-first'
alias tree0='exa --tree --header --icons -a'
alias ffg='find_preview'
alias nt='nvim ~/dotfiles/.config/tmux/.tmux.conf'
alias venv='source ~/git/project/help/.venv/bin/activate'
