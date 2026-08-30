#!/bin/bash

# Ensure full PATH for GNOME background shortcuts
export PATH="/usr/local/bin:/usr/bin:/bin:/snap/bin:$HOME/.local/bin:$PATH"

# 1. Fetch window list
WINDOW_LIST=$(
  python3 - <<'EOF'
import json, subprocess, sys

def get_dbus_json(method, arg=None):
    cmd = [
        "dbus-send", "--session", "--print-reply=literal",
        "--dest=org.gnome.Shell",
        "/org/gnome/Shell/Extensions/Windows",
        f"org.gnome.Shell.Extensions.Windows.{method}"
    ]
    if arg is not None:
        cmd.append(f"uint32:{arg}")
    try:
        raw = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
        if raw.startswith('string "') and raw.endswith('"'):
            raw = raw[8:-1]
        raw = raw.replace('\\"', '"').replace('\\\\', '\\')
        return json.loads(raw)
    except Exception:
        return None

windows = get_dbus_json("List")
if not windows or not isinstance(windows, list):
    sys.exit(0)

for w in windows:
    win_id = w.get("id")
    ws = w.get("workspace", "?")
    wm_class = w.get("wm_class", "Unknown").split('_')[0]
    title = w.get("title", "Untitled")
    
    details = get_dbus_json("Details", win_id)
    mon = details.get("monitor", "?") if isinstance(details, dict) else "?"

    print(f"{win_id}\t[WS {ws} | Mon {mon}]  {wm_class.upper()}  —  {title}")
EOF
)

if [ -z "$WINDOW_LIST" ]; then
  exit 0
fi

# 2. Select interface depending on execution environment
if command -v rofi &>/dev/null; then
  # Brief delay lets GNOME release shortcut hotkeys; -normal-window forces Wayland input focus
  SELECTED=$(echo "$WINDOW_LIST" | rofi -dmenu -i -p "Focus Window" -normal-window)
elif [ -t 0 ] && command -v fzf &>/dev/null; then
  # Interactive CLI shell execution
  SELECTED=$(echo "$WINDOW_LIST" | fzf --reverse --height=40% --prompt="Focus Window > " --delimiter="\t" --with-nth=2..)
else
  # GNOME shortcut execution fallback using a floating Kitty window
  TMP_LIST=$(mktemp)
  TMP_OUT=$(mktemp)
  echo "$WINDOW_LIST" >"$TMP_LIST"

  kitty --name "popup_switcher" \
    --title "Focus Window" \
    -o remember_window_size=no \
    -o initial_window_width=800 \
    -o initial_window_height=400 \
    bash -c "fzf --reverse --prompt='Focus Window > ' --delimiter='\t' --with-nth=2.. < '$TMP_LIST' > '$TMP_OUT'"

  SELECTED=$(cat "$TMP_OUT")
  rm -f "$TMP_LIST" "$TMP_OUT"
fi

# 3. Activate selected window
WIN_ID=$(echo "$SELECTED" | awk -F '\t' '{print $1}')

if [ -n "$WIN_ID" ]; then
  gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell/Extensions/Windows \
    --method org.gnome.Shell.Extensions.Windows.Activate "$WIN_ID" >/dev/null
fi
