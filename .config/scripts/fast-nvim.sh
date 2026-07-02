#!/bin/bash

WINDOW_TITLE="InstantHelpNotes"

# 1. Check for the running window using xdotool
if xdotool search --name "^${WINDOW_TITLE}$" >/dev/null 2>&1; then

  # Instantly focus and raise the window into view
  xdotool search --name "^${WINDOW_TITLE}$" windowactivate

else
  # 2. If NOT found, clear directories and initialize fresh in the background
  mkdir -p "$HOME/git"
  touch "$HOME/git/help.md"

  export TERM=xterm-kitty

  nohup kitty -o linux_display_server=x11 \
    -T "$WINDOW_TITLE" \
    -o remember_window_size=no \
    -o initial_window_width=1100 \
    -o initial_window_height=600 \
    -e nvim "$HOME/git/help.md" >/dev/null 2>&1 &
fi
