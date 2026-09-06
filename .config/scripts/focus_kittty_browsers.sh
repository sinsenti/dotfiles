#!/bin/bash

# Ensure full PATH for GNOME background shortcuts
export PATH="/usr/local/bin:/usr/bin:/bin:/snap/bin:$HOME/.local/bin:$PATH"

APP_TYPE="$1"

if [ -z "$APP_TYPE" ]; then
  echo "Usage: $0 <terminal|firefox|chrome>"
  exit 1
fi

python3 - "$APP_TYPE" <<'EOF'
import json, subprocess, sys

app_type = sys.argv[1].lower()

# App definitions: WM_CLASS search patterns and default launch command
APP_MAP = {
    "terminal": {
        "patterns": ["kitty", "gnome-terminal", "terminal", "alacritty", "wezterm"],
        "cmd": "kitty"
    },
    "firefox": {
        "patterns": ["firefox"],
        "cmd": "firefox"
    },
    "chrome": {
        "patterns": ["chrome", "google-chrome"],
        "cmd": "google-chrome"
    }
}

if app_type not in APP_MAP:
    sys.exit(1)

patterns = APP_MAP[app_type]["patterns"]
launch_cmd = APP_MAP[app_type]["cmd"]

def get_dbus_json(method):
    cmd = [
        "dbus-send", "--session", "--print-reply=literal",
        "--dest=org.gnome.Shell",
        "/org/gnome/Shell/Extensions/Windows",
        f"org.gnome.Shell.Extensions.Windows.{method}"
    ]
    try:
        raw = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
        if raw.startswith('string "') and raw.endswith('"'):
            raw = raw[8:-1]
        raw = raw.replace('\\"', '"').replace('\\\\', '\\')
        return json.loads(raw)
    except Exception:
        return None

windows = get_dbus_json("List")
if windows is None:
    sys.exit(1)

# Filter open windows for the requested app
matching = []
for w in windows:
    wm_class = (w.get("wm_class") or "").lower()
    if any(p in wm_class for p in patterns):
        matching.append(w)

# 1. App is not running -> Launch new instance
if not matching:
    subprocess.Popen([launch_cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    sys.exit(0)

# Check if any window of this app is currently focused
focused_idx = -1
for i, w in enumerate(matching):
    if w.get("focus") is True or w.get("has_focus") is True:
        focused_idx = i
        break

if focused_idx != -1:
    # Currently focused on this app
    if len(matching) == 1:
        # Only 1 window exists -> Do nothing
        sys.exit(0)
    else:
        # Multiple windows exist -> Cycle to the next window
        target_idx = (focused_idx + 1) % len(matching)
        target_id = matching[target_idx]["id"]
else:
    # Coming from another app -> Focus the most recently used window of this app
    target_id = matching[0]["id"]

# 2. Activate target window via DBus
subprocess.run([
    "gdbus", "call", "--session",
    "--dest", "org.gnome.Shell",
    "--object-path", "/org/gnome/Shell/Extensions/Windows",
    "--method", "org.gnome.Shell.Extensions.Windows.Activate",
    str(target_id)
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
EOF
