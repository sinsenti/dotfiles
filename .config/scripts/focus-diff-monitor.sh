#!/bin/bash

# Ensure full PATH for GNOME global shortcuts
export PATH="/usr/local/bin:/usr/bin:/bin:/snap/bin:$HOME/.local/bin:$PATH"

python3 - <<'EOF'
import json, os, subprocess, sys

STATE_FILE = "/tmp/gnome_monitor_focus.json"

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

# 1. Filter for active workspace windows
workspace_windows = [w for w in windows if w.get("in_current_workspace")]
if not workspace_windows:
    workspace_windows = windows

# 2. Fetch Details for each window to get real monitor index
for w in workspace_windows:
    details = get_dbus_json("Details", w["id"])
    if isinstance(details, dict):
        w.update(details)

# 3. Identify currently focused window
focused_win = next((w for w in workspace_windows if w.get("focus") or w.get("has_focus")), workspace_windows[0])
curr_mon = focused_win.get("monitor")

if curr_mon is None:
    sys.exit(0)

# 4. Load persistent state dictionary
state = {}
if os.path.exists(STATE_FILE):
    try:
        with open(STATE_FILE, 'r') as f:
            state = json.load(f)
    except Exception:
        state = {}

# Store current window ID as the active memory for current monitor
state[str(curr_mon)] = focused_win["id"]

try:
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f)
except Exception:
    pass

# 5. Find target monitor and last active window
all_monitors = list({w.get("monitor") for w in workspace_windows if w.get("monitor") is not None})
other_monitors = [m for m in all_monitors if m != curr_mon]

if not other_monitors:
    sys.exit(0)

target_mon = other_monitors[0]
target_win_id = None

# Check if we have a saved window ID for the target monitor
saved_win_id = state.get(str(target_mon))
if saved_win_id:
    # Ensure saved window is still open on target monitor
    if any(w["id"] == saved_win_id and w.get("monitor") == target_mon for w in workspace_windows):
        target_win_id = saved_win_id

# Fallback: Pick first available window on target monitor
if not target_win_id:
    target_win = next((w for w in workspace_windows if w.get("monitor") == target_mon), None)
    if target_win:
        target_win_id = target_win["id"]

# 6. Activate target window
if target_win_id:
    subprocess.run([
        "gdbus", "call", "--session",
        "--dest", "org.gnome.Shell",
        "--object-path", "/org/gnome/Shell/Extensions/Windows",
        "--method", "org.gnome.Shell.Extensions.Windows.Activate",
        str(target_win_id)
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
EOF
