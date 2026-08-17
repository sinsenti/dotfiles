fkill() {
  local pids
  pids=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | sed 1d | \
    fzf --layout=reverse -m --header="[ Tab: Select Multiple | Enter: Kill Process ]" \
        --preview 'ps -p {1} -o pid,user,%cpu,%mem,command' | awk '{print $1}')

  if [ -n "$pids" ]; then
    echo "$pids" | xargs kill -9
    echo "Killed PID(s): $pids"
  fi
}


fenv() {
  local env_file=".env"
  local selected_key

  if [ -f "$env_file" ]; then
    selected_key=$(grep -v '^#' "$env_file" | grep '=' | cut -d= -f1 | \
      fzf --layout=reverse --header="[ Local .env Keys ]" \
          --preview "grep -w ^{} $env_file | cut -d= -f2-")
    
    if [ -n "$selected_key" ]; then
      local val=$(grep -w "^$selected_key" "$env_file" | cut -d= -f2-)
      echo -n "$val" | wl-copy
      echo "Copied value of '$selected_key' to clipboard!"
    fi
  else
    selected_key=$(env | cut -d= -f1 | \
      fzf --layout=reverse --header="[ System Environment Variables ]" \
          --preview 'echo ${(P)1}')
    
    if [ -n "$selected_key" ]; then
      echo -n "${(P)selected_key}" | wl-copy
      echo "Copied value of '$selected_key' to clipboard!"
    fi
  fi
}


copy() {
    local tmpfile
    tmpfile=$(mktemp)
    local cmd=""

    if [ $# -gt 0 ]; then
        cmd="$*"
        eval "$cmd" 2>&1 | tee "$tmpfile"
        {
            printf '$ %s\n' "$cmd"
            sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g; s/\r$//' "$tmpfile"
        } | wl-copy

    elif [ ! -t 0 ]; then
        tee "$tmpfile"
        cmd=$(fc -ln -1 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*|[[:space:]]*copy.*$//')
        [[ -z "$cmd" ]] && cmd="Piped Command"

        {
            printf '$ %s\n' "$cmd"
            sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g; s/\r$//' "$tmpfile"
        } | wl-copy

    else
        echo "Usage: copy <command>   OR   <command> | copy"
        rm -f "$tmpfile"
        return 1
    fi

    rm -f "$tmpfile"
}

copy_file() {
    local file
    if [ $# -eq 0 ]; then
        file=$(fzf --layout=reverse --preview 'bat --color=always --style=numbers {}')
    else
        file="$1"
    fi

    if [ -f "$file" ]; then
        wl-copy < "$file"
        echo "Copied contents of '$file' to clipboard!"
    fi
}

copy_last() {
    local cmd output

    cmd=$(fc -ln -1)
    output=$(eval "$cmd" 2>&1)

    {
        printf '$ %s\n' "$cmd"
        printf '%s\n' "$output"
    } | wl-copy

    printf '%s\n' "$output"
}

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2|*.tbz2) tar xjf "$1" ;;
            *.tar.gz|*.tgz)   tar xzf "$1" ;;
            *.bz2)            bunzip2 "$1" ;;
            *.rar)            unrar x "$1" ;;
            *.gz)             gunzip "$1" ;;
            *.tar)            tar xf "$1" ;;
            *.zip)            unzip "$1" ;;
            *.Z)              uncompress "$1" ;;
            *.7z)             7z x "$1" ;;
            *)                echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}
