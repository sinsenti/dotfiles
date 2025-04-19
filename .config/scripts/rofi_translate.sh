#!/bin/bash

INPUT=$(rofi -dmenu -p "Format: LANG->LANG:text")
if [ -z "$INPUT" ]; then exit 0; fi

# DIRECTION=$(echo "$INPUT" | cut -d: -f1)
# TEXT=$(echo "$INPUT" | cut -d: -f2-)
DIRECTION=$(echo "$INPUT" | cut -d' ' -f1)
TEXT=$(echo "$INPUT" | cut -d' ' -f2-)

case $DIRECTION in
"en,ru")
  SOURCE_LANG="en"
  TARGET_LANG="ru"
  ;;
"ru,en")
  SOURCE_LANG="ru"
  TARGET_LANG="en"
  ;;
"ru")
  SOURCE_LANG="ru"
  TARGET_LANG="en"
  ;;
"кг")
  SOURCE_LANG="ru"
  TARGET_LANG="en"
  ;;
"en,es")
  SOURCE_LANG="en"
  TARGET_LANG="es"
  ;;
"ru,es")
  SOURCE_LANG="ru"
  TARGET_LANG="es"
  ;;
"es,en")
  SOURCE_LANG="es"
  TARGET_LANG="en"
  ;;
*)
  SOURCE_LANG="en"
  TARGET_LANG="ru"
  ;;
esac

TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
CHOICE=$(echo -e "Copy\nClose" | rofi -mesg "$TRANSLATION" -dmenu -p "Done:")
if [ "$CHOICE" = "Copy" ]; then
  echo -n "$TRANSLATION" | wl-copy
fi
