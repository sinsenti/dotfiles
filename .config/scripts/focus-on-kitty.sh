#!/bin/bash

STATE_FILE="/tmp/last_win_before_kitty"

# 1. Fetch raw DBus window list
RAW_DATA=$(dbus-send --session --print-reply=literal --dest=org.gnome.Shell /org/gnome/Shell/Extensions/Windows org.gnome.Shell.Extensions.Windows.List 2>/dev/null)

if [ -z "$RAW_DATA" ]; then
  echo "Error: 'Window Calls' extension is not running or active."
  exit 1
fi

# Clean dbus literal formatting wrappers
JSON_DATA=$(echo "$RAW_DATA" | sed -E 's/^[[:space:]]*string "(.*)"$/\1/' | sed 's/\\"/"/g')

# 2. Extract workspace, Kitty window object, and focus state safely
CURRENT_WORKSPACE=$(echo "$JSON_DATA" | jq -r '[.[] | select(.in_current_workspace == true)][0].workspace // empty')
KITTY_WIN=$(echo "$JSON_DATA" | jq -c '[.[] | select(.wm_class | ascii_downcase | contains("kitty"))][0]')

if [ -z "$KITTY_WIN" ] || [ "$KITTY_WIN" = "null" ]; then
  echo "No open Kitty window found."
  exit 1
fi

KITTY_ID=$(echo "$KITTY_WIN" | jq -r '.id')
IS_KITTY_FOCUSED=$(echo "$KITTY_WIN" | jq -r '.focus // .has_focus // false')

# 3. Toggle behavior
if [ "$IS_KITTY_FOCUSED" = "true" ]; then
  TARGET_WIN_ID=""

  # Retrieve recorded window ID
  if [ -f "$STATE_FILE" ]; then
    LAST_ID=$(cat "$STATE_FILE")
    # Verify recorded window still exists and is not Kitty
    TARGET_WIN_ID=$(echo "$JSON_DATA" | jq -r --arg id "$LAST_ID" '[.[] | select(.id == ($id | tonumber) and (.wm_class | ascii_downcase | contains("kitty") | not))][0].id // empty')
  fi

  # Fallback 1: Top non-Kitty window in current workspace
  if [ -z "$TARGET_WIN_ID" ]; then
    TARGET_WIN_ID=$(echo "$JSON_DATA" | jq -r '[.[] | select(.in_current_workspace == true and (.wm_class | ascii_downcase | contains("kitty") | not))][0].id // empty')
  fi

  # Fallback 2: Top non-Kitty window on any workspace
  if [ -z "$TARGET_WIN_ID" ]; then
    TARGET_WIN_ID=$(echo "$JSON_DATA" | jq -r '[.[] | select(.wm_class | ascii_downcase | contains("kitty") | not)][0].id // empty')
  fi

  if [ -n "$TARGET_WIN_ID" ]; then
    gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.Activate "$TARGET_WIN_ID" >/dev/null
  fi
else
  # Save currently active window ID before focusing Kitty
  CURRENT_FOCUS_ID=$(echo "$JSON_DATA" | jq -r '[.[] | select(.focus == true or .has_focus == true)][0].id // empty')
  if [ -n "$CURRENT_FOCUS_ID" ] && [ "$CURRENT_FOCUS_ID" != "$KITTY_ID" ]; then
    echo "$CURRENT_FOCUS_ID" >"$STATE_FILE"
  fi

  # Bring Kitty to current workspace and focus
  gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.MoveToWorkspace "$KITTY_ID" "$CURRENT_WORKSPACE" >/dev/null
  gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell/Extensions/Windows --method org.gnome.Shell.Extensions.Windows.Activate "$KITTY_ID" >/dev/null
fi
