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

APPLICATION_LIST=""

generate_application_list() {
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
}

lookup_window() {
  local target="$1" label value
  WIN_ID=""
  while IFS=$'\t' read -r label value; do
    if [[ "$label" == "$target" ]]; then
      WIN_ID="$value"
      return 0
    fi
  done <<<"$WINDOW_LIST"
  return 1
}

lookup_application() {
  local target="$1" label desktop_file desktop_id
  APP_DESKTOP=""
  APP_ID=""
  while IFS=$'\t' read -r label desktop_file desktop_id; do
    if [[ "$label" == "$target" ]]; then
      APP_DESKTOP="$desktop_file"
      APP_ID="$desktop_id"
      return 0
    fi
  done <<<"$APPLICATION_LIST"
  return 1
}

launch_application() {
  local label="$1"
  if command -v gio >/dev/null 2>&1; then
    gio launch "$APP_DESKTOP" >/dev/null 2>&1 &
  elif command -v gtk-launch >/dev/null 2>&1; then
    gtk-launch "${APP_ID%.desktop}" >/dev/null 2>&1 &
  else
    search_web "$label"
  fi
}

cleanup_fzf_temp() {
  if [[ -n "${APP_SCAN_PID:-}" ]]; then
    wait "$APP_SCAN_PID" 2>/dev/null || true
  fi
  [[ -z "${TMP_DIR:-}" ]] || rm -rf -- "$TMP_DIR"
}

find_kitty_socket() {
  local socket_path
  KITTY_SOCKET=""
  [[ -n "${XDG_RUNTIME_DIR:-}" ]] || return 1
  command -v kitten >/dev/null 2>&1 || return 1

  for socket_path in "$XDG_RUNTIME_DIR"/kitty-focus-app-search-*.sock; do
    [[ -S "$socket_path" ]] || continue
    KITTY_SOCKET="$socket_path"
    return 0
  done
  return 1
}

parse_fzf_output() {
  FZF_QUERY="${FZF_OUTPUT%%$'\n'*}"
  FZF_SELECTED=""
  if [[ "$FZF_OUTPUT" == *$'\n'* ]]; then
    FZF_SELECTED="${FZF_OUTPUT#*$'\n'}"
  fi
}

run_live_fzf() {
  local windows_file apps_file apps_tmp helper output_file status_file reload_command kitty_status window_id runner
  TMP_DIR=$(mktemp -d) || return 1
  trap cleanup_fzf_temp EXIT

  windows_file="$TMP_DIR/windows"
  apps_file="$TMP_DIR/apps"
  apps_tmp="$TMP_DIR/apps.tmp"
  helper="$TMP_DIR/filter-candidates"
  output_file="$TMP_DIR/output"
  status_file="$TMP_DIR/status"
  printf '%s' "$WINDOW_LIST" >"$windows_file"
  (
    generate_application_list >"$apps_tmp"
    mv -f -- "$apps_tmp" "$apps_file"
  ) &
  APP_SCAN_PID=$!

  cat >"$helper" <<'EOF'
#!/bin/bash
query="$1"
windows_file="$2"
apps_file="$3"

filter_file() {
  fzf --filter="$query" --delimiter=$'\t' --with-nth=1 <"$1" 2>/dev/null || true
}

if [[ -z "$query" ]]; then
  cat "$windows_file"
  exit 0
fi

window_matches=$(filter_file "$windows_file")
if [[ -n "$window_matches" ]]; then
  printf '%s\n' "$window_matches"
else
  while [[ ! -f "$apps_file" ]]; do sleep 0.01; done
  filter_file "$apps_file"
fi
EOF
  chmod +x "$helper"
  printf -v reload_command '%q {q} %q %q' "$helper" "$windows_file" "$apps_file"

  if [[ ! -t 0 ]] && find_kitty_socket; then
    runner="$TMP_DIR/run-fzf"
    cat >"$runner" <<'EOF'
#!/bin/bash
reload_command="$1"
windows_file="$2"
output_file="$3"
status_file="$4"

write_status() {
  local status=$?
  printf '%s' "$status" >"$status_file.tmp"
  mv -f -- "$status_file.tmp" "$status_file"
}
trap write_status EXIT

fzf --disabled --print-query --reverse --height=40% \
  --prompt="Focus Window / App > " --delimiter=$'\t' --with-nth=1 \
  --bind="change:reload($reload_command)" --bind=enter:accept-or-print-query \
  <"$windows_file" >"$output_file"
EOF
    chmod +x "$runner"

    if window_id=$(kitten @ --to "unix:$KITTY_SOCKET" launch \
      --type=os-window \
      --title="Focus Window / App" \
      --os-window-class=popup_switcher \
      --os-window-title="Focus Window / App" \
      --os-window-state=normal \
      --env "PATH=$PATH" \
      "$runner" "$reload_command" "$windows_file" "$output_file" "$status_file" 2>/dev/null); then
      kitten @ --to "unix:$KITTY_SOCKET" resize-os-window \
        --match "id:$window_id" --unit pixels --width 800 --height 400 >/dev/null 2>&1 || true
      while [[ ! -f "$status_file" ]]; do
        if ! kitten @ --to "unix:$KITTY_SOCKET" ls 2>/dev/null | python3 -c '
import json, sys
wanted = sys.argv[1]
windows = json.load(sys.stdin)
found = any(
    str(window.get("id")) == wanted
    for os_window in windows
    for tab in os_window.get("tabs", [])
    for window in tab.get("windows", [])
)
sys.exit(0 if found else 1)
' "$window_id"; then
          break
        fi
        sleep 0.1
      done
      FZF_OUTPUT=$(<"$output_file") 2>/dev/null || FZF_OUTPUT=""
      if [[ -f "$status_file" ]]; then
        FZF_STATUS=$(<"$status_file")
      else
        FZF_STATUS=130
      fi
      return 0
    fi
  fi

  if [[ -t 0 ]]; then
    FZF_OUTPUT=$(fzf --disabled --print-query --reverse --height=40% \
      --prompt="Focus Window / App > " --delimiter=$'\t' --with-nth=1 \
      --bind="change:reload($reload_command)" --bind=enter:accept-or-print-query <"$windows_file")
    FZF_STATUS=$?
    return 0
  fi

  command -v kitty >/dev/null 2>&1 || return 1
  kitty --name "popup_switcher" \
    --title "Focus Window / App" \
    -o remember_window_size=no \
    -o initial_window_width=800 \
    -o initial_window_height=400 \
    bash -c '
      fzf --disabled --print-query --reverse --height=40% --prompt="Focus Window / App > " \
        --delimiter="$(printf "\\t")" --with-nth=1 --bind="change:reload($1)" \
        --bind=enter:accept-or-print-query <"$2" >"$3"
      printf "%s" "$?" >"$4"
    ' _ "$reload_command" "$windows_file" "$output_file" "$status_file"
  kitty_status=$?
  FZF_OUTPUT=$(<"$output_file") 2>/dev/null || FZF_OUTPUT=""
  if [[ -f "$status_file" ]]; then
    FZF_STATUS=$(<"$status_file")
  else
    FZF_STATUS=$kitty_status
  fi
}

WIN_ID=""
APP_DESKTOP=""
APP_ID=""
SELECTED_LABEL=""
SEARCH_QUERY=""

if command -v fzf &>/dev/null && { [[ -t 0 ]] || command -v kitty &>/dev/null; }; then
  run_live_fzf || exit 0
  if (( FZF_STATUS == 130 )); then
    exit 0
  fi
  if [[ -f "$TMP_DIR/apps" ]]; then
    APPLICATION_LIST=$(<"$TMP_DIR/apps")
  fi
  parse_fzf_output

  if [[ -n "$FZF_SELECTED" ]]; then
    SELECTED_LABEL="${FZF_SELECTED%%$'\t'*}"
    if lookup_window "$SELECTED_LABEL"; then
      :
    elif lookup_application "$SELECTED_LABEL"; then
      launch_application "$SELECTED_LABEL"
    else
      SEARCH_QUERY="${FZF_QUERY:-$SELECTED_LABEL}"
      search_web "$SEARCH_QUERY"
    fi
  else
    search_web "$FZF_QUERY"
  fi

elif command -v rofi &>/dev/null; then
  ROFI_THEME='configuration { font: "JetBrainsMono Nerd Font SemiBold 11"; } element-text { font: "JetBrainsMono Nerd Font SemiBold 11"; }'
  WINDOW_SELECTION=$(printf '%s' "$WINDOW_LIST" | cut -f1 | rofi -dmenu -i -format s -p "Focus Window / App" -normal-window \
    -theme-str "$ROFI_THEME")

  if [[ -n "$WINDOW_SELECTION" ]]; then
    if lookup_window "$WINDOW_SELECTION"; then
      :
    else
      APPLICATION_LIST=$(generate_application_list)
      if [[ -n "$APPLICATION_LIST" ]]; then
        APP_SELECTION=$(printf '%s' "$APPLICATION_LIST" | cut -f1 | rofi -dmenu -i -format s -p "Launch App" \
          -filter "$WINDOW_SELECTION" -normal-window -theme-str "$ROFI_THEME")
        if [[ -n "$APP_SELECTION" ]]; then
          if lookup_application "$APP_SELECTION"; then
            launch_application "$APP_SELECTION"
          else
            search_web "$APP_SELECTION"
          fi
        fi
      else
        search_web "$WINDOW_SELECTION"
      fi
    fi
  fi
else
  exit 0
fi

if [[ -n "$WIN_ID" ]]; then
  gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.Activate "$WIN_ID" >/dev/null
fi
