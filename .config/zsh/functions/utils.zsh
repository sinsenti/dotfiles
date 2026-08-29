preexec() { printf '%s\n%s\n' "$PWD" "$1" > ~/.cache/last_cmd }

record_myself() {
    # 1. Define output directory and ensure it exists
    local out_dir="$HOME/Videos/self_recording"
    mkdir -p "$out_dir"

    # 2. Generate timestamped filename
    local filename="$(date +'%d-%m-%Y_%H-%M').mp4"
    local filepath="$out_dir/$filename"

    echo -e "\033[1;31m🎥 [Recording Started]\033[0m"
    echo -e "Saving to: \033[1;36m$filepath\033[0m"
    echo -e "Press \033[1;33m[q]\033[0m in this terminal to stop recording.\n"

    # 3. Stream at 60 FPS; split immediately to isolate preview from recording filters
    ffmpeg -thread_queue_size 1024 -f v4l2 -input_format mjpeg -video_size 1920x1080 -framerate 60 -i /dev/video0 \
           -thread_queue_size 1024 -f pulse -i default \
           -filter_complex "[0:v]split=2[prev_raw][rec_raw]; \
                            [prev_raw]format=yuv420p[prev]; \
                            [rec_raw]hqdn3d=1.2:1.2:2:2,scale=in_range=pc:out_range=tv[rec]" \
           -map "[rec]" -map 1:a \
               -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p \
               -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
               -movflags +faststart \
               -c:a aac -b:a 320k -ar 48000 \
               "$filepath" \
           -map "[prev]" \
               -c:v rawvideo -pix_fmt yuv420p -f nut - | mpv --profile=low-latency --untimed --no-cache --demuxer-thread=no --vo=gpu --title="Live Camera Preview" -

    echo -e "\n\033[1;32m✅ [Recording Saved Successfully]\033[0m"
    echo "$filepath"
}

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
