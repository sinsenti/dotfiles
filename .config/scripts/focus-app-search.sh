#!/bin/bash

export PATH="/usr/local/bin:/usr/bin:/bin:/snap/bin:$HOME/.local/bin:$PATH"

search_web() {
  local query="$1" url word
  [ -n "$query" ] || return 0
  command -v xdg-open >/dev/null 2>&1 || return 1

  if [[ "$query" == "dict "* ]]; then
    word="${query#dict }"
    if [[ -n "${word//[[:space:]]/}" ]]; then
      url=$(python3 -c 'import sys, urllib.parse; print("https://dictionary.cambridge.org/dictionary/english/" + urllib.parse.quote(sys.argv[1].strip(), safe=""))' "$word") || return 1
    fi
  fi

  if [ -z "$url" ]; then
    url=$(python3 -c 'import sys, urllib.parse; print("https://www.google.com/search?" + urllib.parse.urlencode({"q": sys.argv[1]}))' "$query") || return 1
  fi
  xdg-open "$url" >/dev/null 2>&1 &
}

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

APPLICATION_LIST=$(
  python3 - <<'EOF'
import configparser
import os
from collections import Counter
from pathlib import Path

xdg_data_home = os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))
xdg_data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
roots = [Path(xdg_data_home), *(Path(path) for path in xdg_data_dirs if path)]
entries = []
seen = set()

for root in roots:
    app_dir = root / "applications"
    try:
        desktop_files = sorted(app_dir.rglob("*.desktop"))
    except OSError:
        continue

    for desktop_file in desktop_files:
        desktop_id = desktop_file.relative_to(app_dir).as_posix().replace("/", "-")
        if desktop_id in seen:
            continue
        seen.add(desktop_id)

        parser = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            parser.read(desktop_file, encoding="utf-8")
            entry = parser["Desktop Entry"]
        except (OSError, KeyError, configparser.Error, UnicodeError):
            continue

        if entry.get("Type") != "Application":
            continue
        if entry.get("Hidden", "false").lower() == "true" or entry.get("NoDisplay", "false").lower() == "true":
            continue

        name = entry.get("Name", "").replace("\t", " ").replace("\n", " ").strip()
        if name:
            entries.append((name, str(desktop_file), desktop_id))

name_counts = Counter(name.casefold() for name, _, _ in entries)
for name, desktop_file, desktop_id in entries:
    label = f"{name}"
    if name_counts[name.casefold()] > 1:
        label += f" [{desktop_id}]"
    print(f"{label}\t{desktop_file}\t{desktop_id}")
EOF
)

PICKER_LIST="$WINDOW_LIST"
if [ -n "$APPLICATION_LIST" ]; then
  if [ -n "$PICKER_LIST" ]; then
    PICKER_LIST+=$'\n'
  fi
  PICKER_LIST+="$APPLICATION_LIST"
fi

if [ -z "$PICKER_LIST" ] && ! command -v rofi &>/dev/null; then
  exit 0
fi

if command -v rofi &>/dev/null; then
  SELECTED=$(printf '%s' "$PICKER_LIST" | cut -f1 | rofi -dmenu -i -format s -p "Focus Window / App" -normal-window \
    -theme-str 'configuration { font: "JetBrainsMono Nerd Font SemiBold 11"; } element-text { font: "JetBrainsMono Nerd Font SemiBold 11"; }')

elif [ -t 0 ] && command -v fzf &>/dev/null; then
  SELECTED=$(printf '%s' "$PICKER_LIST" | fzf --reverse --height=40% --prompt="Focus Window / App > " --delimiter="\t" --with-nth=1)

else
  TMP_LIST=$(mktemp)
  TMP_OUT=$(mktemp)
  printf '%s\n' "$PICKER_LIST" >"$TMP_LIST"

  kitty --name "popup_switcher" \
    --title "Focus Window / App" \
    -o remember_window_size=no \
    -o initial_window_width=800 \
    -o initial_window_height=400 \
    bash -c "fzf --reverse --prompt='Focus Window / App > ' --delimiter='\t' --with-nth=1 < '$TMP_LIST' > '$TMP_OUT'"

  SELECTED=$(<"$TMP_OUT")
  rm -f "$TMP_LIST" "$TMP_OUT"
fi

if [ -n "$SELECTED" ]; then
  SELECTED_LABEL="${SELECTED%%$'\t'*}"
  WIN_ID=""
  APP_DESKTOP=""
  APP_ID=""

  while IFS=$'\t' read -r label value; do
    if [[ "$label" == "$SELECTED_LABEL" ]]; then
      WIN_ID="$value"
      break
    fi
  done <<<"$WINDOW_LIST"

  if [ -z "$WIN_ID" ]; then
    while IFS=$'\t' read -r label desktop_file desktop_id; do
      if [[ "$label" == "$SELECTED_LABEL" ]]; then
        APP_DESKTOP="$desktop_file"
        APP_ID="$desktop_id"
        break
      fi
    done <<<"$APPLICATION_LIST"
  fi

  if [ -n "$WIN_ID" ]; then
    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.Activate "$WIN_ID" >/dev/null

  elif [ -n "$APP_DESKTOP" ]; then
    if command -v gio >/dev/null 2>&1; then
      gio launch "$APP_DESKTOP" >/dev/null 2>&1 &
    elif command -v gtk-launch >/dev/null 2>&1; then
      gtk-launch "${APP_ID%.desktop}" >/dev/null 2>&1 &
    else
      search_web "$SELECTED_LABEL"
    fi
  else
    search_web "$SELECTED_LABEL"
  fi
fi
