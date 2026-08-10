#!/bin/bash
# Fast Area-Selection OCR → Kitty/Tmux Integration

set -euo pipefail

# Use RAM (/dev/shm) for zero-latency image processing
readonly SHM_IMG="/dev/shm/ocr_snippet.png"
readonly DOC_FILE="$HOME/Documents/search.txt"

main() {
  # 1. Ensure target directory exists
  mkdir -p "$HOME/Documents"

  # 2. Interactive Area Selection Screenshot
  gnome-screenshot -a -f "$SHM_IMG" || exit 0

  # Exit cleanly if user cancels selection (e.g., presses Esc)
  if [ ! -f "$SHM_IMG" ]; then
    echo "Screenshot selection cancelled."
    exit 0
  fi

  # 3. Ultra-Fast OCR → search.txt & Wayland Clipboard
  tesseract "$SHM_IMG" stdout --psm 6 2>/dev/null | tee "$DOC_FILE" | wl-copy
  rm -f "$SHM_IMG" 2>/dev/null || true

  # 4. Check for active Kitty window ID safely
  JSON_DATA=$(dbus-send --session --print-reply=literal --dest=org.gnome.Shell \
    /org/gnome/Shell/Extensions/Windows org.gnome.Shell.Extensions.Windows.List 2>/dev/null || true)

  CURRENT_WORKSPACE=$(echo "${JSON_DATA:-}" | jq '.[]? | select(.in_current_workspace == true) | .workspace' 2>/dev/null | head -n 1)
  KITTY_ID=$(echo "${JSON_DATA:-}" | jq '.[]? | select((.wm_class // "") | ascii_downcase | contains("kitty")) | .id' 2>/dev/null | head -n 1)

  # 5. Open or Focus Terminal
  if [ -n "$KITTY_ID" ] && [ -n "$CURRENT_WORKSPACE" ]; then
    # SCENARIO A: Kitty is ALREADY OPEN -> Teleport & focus existing window
    gdbus call --session --dest org.gnome.Shell \
      --object-path /org/gnome/Shell/Extensions/Windows \
      --method org.gnome.Shell.Extensions.Windows.MoveToWorkspace "$KITTY_ID" "$CURRENT_WORKSPACE" >/dev/null 2>&1 || true
    gdbus call --session --dest org.gnome.Shell \
      --object-path /org/gnome/Shell/Extensions/Windows \
      --method org.gnome.Shell.Extensions.Windows.Activate "$KITTY_ID" >/dev/null 2>&1 || true

    if tmux info >/dev/null 2>&1; then
      tmux new-window -c "$HOME/Documents" "nvim search.txt"
    else
      tmux new-session -d -c "$HOME/Documents" "nvim search.txt"
    fi

  else
    # SCENARIO B: Kitty is NOT OPEN -> Launch new Kitty window directly
    if tmux info >/dev/null 2>&1; then
      tmux new-window -c "$HOME/Documents" "nvim search.txt"
      kitty -e tmux attach-session &
    else
      kitty -e tmux new-session -c "$HOME/Documents" "nvim search.txt" &
    fi
  fi
}

main "$@"
