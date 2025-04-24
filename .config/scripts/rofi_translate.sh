#!/bin/bash

INPUT=$(rofi -dmenu -p "Format: LANG,LANG text (or just text for en->ru)")
if [ -z "$INPUT" ]; then exit 0; fi

DIRECTION=$(echo "$INPUT" | cut -d' ' -f1)
TEXT=$(echo "$INPUT" | cut -d' ' -f2-)

# List of valid directions
if [[ "$DIRECTION" == "en,ru" ]] || [[ "$DIRECTION" == "ru,en" ]] ||
  [[ "$DIRECTION" == "ru" ]] || [[ "$DIRECTION" == "кг" ]] ||
  [[ "$DIRECTION" == "en,es" ]] || [[ "$DIRECTION" == "ru,es" ]] ||
  [[ "$DIRECTION" == "es,en" ]]; then

  # Set languages based on direction
  if [ "$DIRECTION" = "en,ru" ]; then
    SOURCE_LANG="en"
    TARGET_LANG="ru"
  elif [ "$DIRECTION" = "ru,en" ] || [ "$DIRECTION" = "ru" ] || [ "$DIRECTION" = "кг" ]; then
    SOURCE_LANG="ru"
    TARGET_LANG="en"
  elif [ "$DIRECTION" = "en,es" ]; then
    SOURCE_LANG="en"
    TARGET_LANG="es"
  elif [ "$DIRECTION" = "ru,es" ]; then
    SOURCE_LANG="ru"
    TARGET_LANG="es"
  elif [ "$DIRECTION" = "es,en" ]; then
    SOURCE_LANG="es"
    TARGET_LANG="en"
  fi

else
  # No direction found, treat all input as text, default en->ru
  SOURCE_LANG="en"
  TARGET_LANG="ru"
  TEXT="$INPUT"
fi

TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
CHOICE=$(echo -e "Copy\nClose" | rofi -mesg "$TRANSLATION" -dmenu -p "Done:")
if [ "$CHOICE" = "Copy" ]; then
  echo -n "$TRANSLATION" | wl-copy
fi
