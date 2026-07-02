#!/bin/bash
# OCR4Linux Ultra-Fast: Updated for GNOME/Wayland

set -euo pipefail

readonly DIR="$HOME/Pictures/Screenshots"
readonly IMG="$DIR/screenshot_$(date +%d%m%Y_%H%M%S).png"
readonly LANGUAGES="eng"

main() {
  mkdir -p "$DIR"

  # PIPELINE 1: Use GNOME's native area selection tool
  gnome-screenshot -a -f "$IMG"

  # PIPELINE 2: Direct OCR → clipboard
  python3 -c "
from PIL import Image
import pytesseract, subprocess, sys
img = Image.open('$IMG')
text = pytesseract.image_to_string(img, lang='$LANGUAGES', config='--oem 3 --psm 6')
subprocess.run(['wl-copy'], input=text.encode('utf-8'))
print('✓ OCR → clipboard', file=sys.stderr)
" &

  # Parallel notifications (non-blocking)
  # notify-send "OCR Done" "Eng → clipboard ($IMG)" -t 1500 &
}

main "$@"
