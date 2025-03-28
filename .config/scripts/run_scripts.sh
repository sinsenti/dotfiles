#!/bin/bash

SCRIPT_DIR="$HOME/dotfiles/.config/scripts"

# Get script selection via Rofi (show only file names)
chosen=$(find "$SCRIPT_DIR" -maxdepth 1 -type f -executable -printf "%f\n" | rofi -dmenu -p "Select script:")

# Execute the selected script if a valid selection was made
if [[ -n "$chosen" ]]; then
  bash "$SCRIPT_DIR/$chosen"
fi
