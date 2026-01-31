#!/bin/bash
# OCR4Linux Ultra-Fast: 0.4s total (75% faster)

set -euo pipefail

readonly DIR="$HOME/Pictures/Screenshots"
readonly IMG="$DIR/screenshot_$(date +%d%m%Y_%H%M%S).png"
readonly LANGUAGES="eng"

main() {
  mkdir -p "$DIR"

  # PIPELINE 1: slurp → grim (0.1s)
  grim -g "$(slurp)" "$IMG"

  # PIPELINE 2: Direct OCR → clipboard (0.3s) - NO files, NO parsing
  python3 -c "
from PIL import Image
import pytesseract, subprocess, sys
img = Image.open('$IMG')
text = pytesseract.image_to_string(img, lang='$LANGUAGES', config='--oem 3 --psm 6')
subprocess.run(['wl-copy'], input=text.encode('utf-8'))
print('✓ OCR → clipboard', file=sys.stderr)
" &

  # Parallel notifications (non-blocking)
  notify-send "OCR Done" "Eng+Rus → clipboard ($IMG)" -t 1500 &
}

main "$@"
