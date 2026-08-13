# Smart Neovim Launcher (Session, Directory, Git, or File)
unalias n 2>/dev/null
n() {
    if [[ "$1" == "-s" || "$1" == "--select" ]]; then
        nvim -c 'lua vim.schedule(function() require("persistence").select() end)'
        return
    fi

    if [[ "$1" == "-g" || "$1" == "--git" ]]; then
        nvim -c 'lua vim.schedule(function() require("persistence").load(); require("neogit").open({ kind = "replace" }) end)'
        return
    fi

    if [[ -d "$1" ]]; then
        cd "$1" || return
        nvim -c 'lua vim.schedule(function() require("persistence").load() end)'
        return
    fi

    if [ $# -eq 0 ]; then
        nvim -c 'lua vim.schedule(function() require("persistence").load() end)'
    else
        nvim "$@"
    fi
}

# Zoxide Jump + Restore Session
zn() {
    local target
    if [ $# -eq 0 ]; then
        target=$(zoxide query -i)
    else
        target=$(zoxide query "$@")
    fi
    if [ -n "$target" ]; then
        cd "$target" && n
    fi
}

# Zoxide + Yazi Launcher
zy() {
    local target
    if [ $# -eq 0 ]; then
        target=$(zoxide query -i)
    else
        target=$(zoxide query "$@")
    fi
    if [ -n "$target" ]; then
        y "$target"
    fi
}

# Yazi CWD Wrapper
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# Fuzzy Subdirectory Jump
fcd() {
    local dir
    dir=$(find . -type d -not -path '*/.*' 2>/dev/null | fzf --layout=reverse --header="[ Select Subdirectory ]")
    [ -n "$dir" ] && cd "$dir"
}

# Ripgrep + FZF + Neovim Live Preview
find_preview() {
  rg --hidden --line-number --color=always "$1" \
    | fzf --layout=reverse --ansi \
          --preview 'echo "\033[1;35mFile: $(echo {} | cut -d: -f1)\033[0m" && bat --style=numbers --color=always --theme=Dracula --line-range :500 $(echo {} | cut -d: -f1) --highlight-line $(echo {} | cut -d: -f2)' \
          --preview-window=right:60%:wrap \
    | while IFS=: read -r file line _; do
        nvim +"$line" "$file"
      done
}
