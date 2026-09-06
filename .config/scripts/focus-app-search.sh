#!/bin/bash

export PATH="/usr/local/bin:/usr/bin:/bin:/snap/bin:$HOME/.local/bin:$PATH"

WINDOW_LIST=$(
  python3 - <<'EOF'
import json, subprocess, sys

cmd = [
    "dbus-send", "--session", "--print-reply=literal",
    "--dest=org.gnome.Shell",
    "/org/gnome/Shell/Extensions/Windows",
    "org.gnome.Shell.Extensions.Windows.List"
]

try:
    raw = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    if raw.startswith('string "') and raw.endswith('"'):
        raw = raw[8:-1]
    raw = raw.replace('\\"', '"').replace('\\\\', '\\')
    windows = json.loads(raw)
except Exception:
    sys.exit(0)

if not windows or not isinstance(windows, list):
    sys.exit(0)

for w in windows:
    win_id = w.get("id")
    ws = w.get("workspace", "?")
    wm_class = w.get("wm_class", "Unknown").split('_')[0]
    title = w.get("title", "Untitled")
    mon = w.get("monitor", "?") # Extracted directly from List response

    print(f"{wm_class.upper()}  —  {title}  [WS {ws} | Mon {mon}]\t{win_id}")
EOF
)

if [ -z "$WINDOW_LIST" ]; then
  exit 0
fi

if command -v rofi &>/dev/null; then
  INDEX=$(echo "$WINDOW_LIST" | cut -f1 | rofi -dmenu -i -format i -p "Focus Window" -normal-window \
    -theme-str 'configuration { font: "JetBrainsMono Nerd Font SemiBold 11"; } element-text { font: "JetBrainsMono Nerd Font SemiBold 11"; }')

  if [ -n "$INDEX" ]; then
    WIN_ID=$(echo "$WINDOW_LIST" | sed -n "$((INDEX + 1))p" | cut -f2)
  fi

elif [ -t 0 ] && command -v fzf &>/dev/null; then
  SELECTED=$(echo "$WINDOW_LIST" | fzf --reverse --height=40% --prompt="Focus Window > " --delimiter="\t" --with-nth=1)
  WIN_ID=$(echo "$SELECTED" | cut -f2)

else
  TMP_LIST=$(mktemp)
  TMP_OUT=$(mktemp)
  echo "$WINDOW_LIST" >"$TMP_LIST"

  kitty --name "popup_switcher" \
    --title "Focus Window" \
    -o remember_window_size=no \
    -o initial_window_width=800 \
    -o initial_window_height=400 \
    bash -c "fzf --reverse --prompt='Focus Window > ' --delimiter='\t' --with-nth=1 < '$TMP_LIST' | cut -f2 > '$TMP_OUT'"

  WIN_ID=$(cat "$TMP_OUT")
  rm -f "$TMP_LIST" "$TMP_OUT"
fi

if [ -n "$WIN_ID" ]; then
  gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell/Extensions/Windows \
    --method org.gnome.Shell.Extensions.Windows.Activate "$WIN_ID" >/dev/null
fi
