#!/bin/bash

# 1. Fetch the active window layout from the DBus extension interface
JSON_DATA=$(dbus-send --session --print-reply=literal --dest=org.gnome.Shell /org/gnome/Shell/Extensions/Windows org.gnome.Shell.Extensions.Windows.List 2>/dev/null)

if [ -z "$JSON_DATA" ]; then
  echo "Error: 'Window Calls' extension is not running or active."
  exit 1
fi

# 2. Extract the target workspace (where Firefox is) and Kitty's window ID
CURRENT_WORKSPACE=$(echo "$JSON_DATA" | jq '.[] | select(.in_current_workspace == true) | .workspace' | head -n 1)
KITTY_ID=$(echo "$JSON_DATA" | jq '.[] | select(.wm_class | ascii_downcase | contains("kitty")) | .id' | head -n 1)

if [ -z "$KITTY_ID" ]; then
  echo "No open Kitty window found."
  exit 1
fi

# 3. Teleport Kitty over to your current workspace and raise it over Firefox
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.MoveToWorkspace "$KITTY_ID" "$CURRENT_WORKSPACE" >/dev/null
gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.Activate "$KITTY_ID" >/dev/null
