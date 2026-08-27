# Smart Neovim Launcher (Session, Directory, Git, or File)
unalias n 2>/dev/null

ndry() {
  local query="$1"
  local -a selected

  selected=("${(@f)$(fzf ${query:+-q "$query"} \
                         -m \
                         --bind 'enter:transform:[ $FZF_SELECT_COUNT -eq 0 ] && echo "select-all+accept" || echo "accept"' \
                         --preview 'bat --color=always --style=header,grid --line-range :300 {} 2>/dev/null || head -n 100 {}' \
                         --header 'ENTER: Open ALL matching (or selected) | TAB: Select specific file(s)')}")

  # Open selected or matching files in Neovim/EDITOR
  if (( ${#selected[@]} > 0 && ${#selected[1]} > 0 )); then
    ${EDITOR:-nvim} "${selected[@]}"
  fi
}

f() {
    local cmd
    local header_text="[ Select command from history ]"
    if [ $# -gt 0 ]; then
        header_text="[ History query: '$*' ]"
    fi

    # Deduplicate history (newest first) and stream to FZF
    cmd=$(fc -ln 1 | \
          awk '{ a[NR] = $0 } END { for (i = NR; i > 0; i--) if (!seen[a[i]]++) print a[i] }' | \
          fzf --layout=reverse --no-sort --header="$header_text" --query="$*")

    if [ -n "$cmd" ]; then
        print -s "$cmd" # Push to Zsh history buffer
        echo -e "\033[1;32mExecuting:\033[0m $cmd"
        eval "$cmd"
    fi
}

fcurl() {
  local cmd
  cmd=$(fc -ln 1 | grep -E '^\s*curl\b' | \
        awk '{ a[NR] = $0 } END { for (i = NR; i > 0; i--) if (!seen[a[i]]++) print a[i] }' | \
        fzf --layout=reverse --no-sort --header="[ Select curl command ]" --query="$*")

  if [ -n "$cmd" ]; then
    print -s "$cmd" # Push to command history buffer
    echo -e "\033[1;32mExecuting:\033[0m $cmd"
    eval "$cmd"
  fi
}

fn() {
  local file
  file=$(fzf --preview 'bat --color=always --style=numbers {} 2>/dev/null || cat {}')
  if [ -n "$file" ]; then
    nvim "$file"
  fi
}

n() {
    # 1. Interactive session selection
    if [[ "$1" == "-s" || "$1" == "--select" ]]; then
        nvim -c 'lua vim.schedule(function() require("persistence").select() end)'
        return
    fi

    # 2. Git mode
    if [[ "$1" == "-g" || "$1" == "--git" ]]; then
        nvim -c 'lua vim.schedule(function() require("persistence").load(); require("neogit").open({ kind = "replace" }) end)'
        return
    fi

    # 3. Clean start in current directory (bypasses session restore)
    if [[ "$1" == "." || "$1" == "./" ]]; then
        nvim
        return
    fi

    # 4. Jump to directory and load its saved session
    if [[ -d "$1" ]]; then
        cd "$1" || return
        nvim -c 'lua vim.schedule(function() require("persistence").load() end)'
        return
    fi

    # 5. No arguments: Restore session in current directory
    if [ $# -eq 0 ]; then
        nvim -c 'lua vim.schedule(function() require("persistence").load() end)'
    else
        # 6. Specific file(s) passed (e.g. `n main.py`)
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
