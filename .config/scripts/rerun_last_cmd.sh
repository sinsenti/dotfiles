#!/usr/bin/env bash
shopt -s expand_aliases

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/last_cmd"

# Exit silently if no tracked state exists
[[ ! -f "$STATE_FILE" ]] && exit 0

# Read dir (line 1) and command (line 2)
{
  read -r DIR
  read -r CMD
} <"$STATE_FILE"

[[ -z "$DIR" || -z "$CMD" ]] && exit 0

# Format directory for display (replace /home/user with ~)
DISPLAY_DIR="${DIR/#$HOME/~}"

# Safely escape HTML/Pango characters using native Bash substitution
SAFE_DIR="${DISPLAY_DIR//&/&amp;}"
SAFE_DIR="${SAFE_DIR//</&lt;}"
SAFE_DIR="${SAFE_DIR//>/&gt;}"

SAFE_CMD="${CMD//&/&amp;}"
SAFE_CMD="${SAFE_CMD//</&lt;}"
SAFE_CMD="${SAFE_CMD//>/&gt;}"

# Show Confirmation Modal (Intro title removed, font size increased to x-large)
if zenity --question \
  --title="Command Rerun" \
  --text="<b>Dir:</b>\n<span size=\"x-large\"><tt>$SAFE_DIR</tt></span>\n\n<b>Cmd:</b>\n<span size=\"xx-large\"><b><tt>$SAFE_CMD</tt></b></span>" \
  --ok-label="Run (Enter)" \
  --cancel-label="Cancel (Esc)" \
  --width=550; then

  # If we get here, the user pressed Enter. Run headlessly!
  OUTPUT=$(cd "$DIR" 2>&1 && eval "$CMD" 2>&1)
  STATUS=$?

  # Notify desktop showing directory, command, and terminal output
  notify-send "⚡ Reran (${STATUS})" "Dir: $DISPLAY_DIR\nCmd: $CMD\n\n${OUTPUT:-(No output)}"
fi
