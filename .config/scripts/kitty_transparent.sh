#!/usr/bin/env bash

CONF="$HOME/.config/kitty/kitty.conf"

toggle() {
  # 1 -> 0.8
  sed -i 's/^\([[:space:]]*background_opacity[[:space:]]\+\)1\([[:space:]]*\)\(.*\)$/\10.8\2\3/' "$CONF"
  kitty --class kitty-float nvim ~/git/obsidian/Help.md
  # 0.8 -> 1
  sed -i 's/^\([[:space:]]*background_opacity[[:space:]]\+\)0\.8\([[:space:]]*\)\(.*\)$/\11\2\3/' "$CONF"
}

# toggle() {
#   # 1 -> 0.6
#   sed -i 's/^\([[:space:]]*background_opacity[[:space:]]\+\)1\([[:space:]]*\)\(.*\)$/\10.6\2\3/' "$CONF"
#   kitty --class kitty-float nvim ~/git/obsidian/Help.md
#   # 0.6 -> 1
#   sed -i 's/^\([[:space:]]*background_opacity[[:space:]]\+\)0\.6\([[:space:]]*\)\(.*\)$/\11\2\3/' "$CONF"
# }
toggle
