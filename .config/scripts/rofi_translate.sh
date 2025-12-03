#!/bin/bash

INPUT=$(rofi -dmenu -p "Format: LANG,LANG text (or just text for en->ru)")

if [ $? -ne 0 ]; then
  exit 0
fi
if [ -z "$INPUT" ]; then
  INPUT=$(wl-paste)
  if [ -z "$INPUT" ]; then
    exit 0
  fi
fi

DIRECTION=$(echo "$INPUT" | cut -d' ' -f1)
TEXT=$(echo "$INPUT" | cut -d' ' -f2-)

# List of valid directions
if [[ "$DIRECTION" == "en,ru" ]] || [[ "$DIRECTION" == "ru,en" ]] ||
  [[ "$DIRECTION" == "ru" ]] || [[ "$DIRECTION" == "кг" ]] ||
  [[ "$DIRECTION" == "en,es" ]] || [[ "$DIRECTION" == "ru,es" ]] ||
  [[ "$DIRECTION" == "es,en" ]] || [[ "$DIRECTION" == "re" ]]; then

  # Set languages based on direction
  if [ "$DIRECTION" = "en,ru" ]; then
    TARGET_LANG="ru"
    TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
  elif [ "$DIRECTION" = "ru,en" ] || [ "$DIRECTION" = "ru" ] || [ "$DIRECTION" = "кг" ]; then
    TARGET_LANG="en"
    TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
  elif [ "$DIRECTION" = "en,es" ]; then
    TARGET_LANG="es"
    TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
  elif [ "$DIRECTION" = "ru,es" ]; then
    TARGET_LANG="es"
    TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
  elif [ "$DIRECTION" = "es,en" ]; then
    TARGET_LANG="en"
    TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
  elif [ "$DIRECTION" = "re" ]; then
    TARGET_LANG="ru"
    # TEXT="$INPUT"
    wl-copy <<<"$TEXT"
    TMP_RU=$(trans -b "en:ru" "$TEXT")
    wl-copy <<<"$TMP_RU"
    TRANSLATION=$(trans -b "ru:en" "$TMP_RU")

  fi

else
  TARGET_LANG="ru"
  TEXT="$INPUT"
  TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
fi

CHOICE=$(echo -e "Copy\nClose" | rofi -mesg "$TRANSLATION" -dmenu -p "Done:")
if [ "$CHOICE" = "Copy" ]; then
  echo -n "$TRANSLATION" | wl-copy
elif [ "$CHOICE" = "Close" ]; then
  exit 0
else
  while true; do
    INPUT=$CHOICE
    echo "Printing input: $INPUT"
    if [ $? -ne 0 ]; then
      exit 0
    fi
    DIRECTION=$(echo "$INPUT" | cut -d' ' -f1)
    TEXT=$(echo "$INPUT" | cut -d' ' -f2-)

    # List of valid directions
    if [[ "$DIRECTION" == "en,ru" ]] || [[ "$DIRECTION" == "ru,en" ]] ||
      [[ "$DIRECTION" == "ru" ]] || [[ "$DIRECTION" == "кг" ]] ||
      [[ "$DIRECTION" == "en,es" ]] || [[ "$DIRECTION" == "ru,es" ]] ||
      [[ "$DIRECTION" == "es,en" ]]; then

      # Set languages based on direction
      if [ "$DIRECTION" = "en,ru" ]; then
        TARGET_LANG="ru"
      elif [ "$DIRECTION" = "ru,en" ] || [ "$DIRECTION" = "ru" ] || [ "$DIRECTION" = "кг" ]; then
        TARGET_LANG="en"
      elif [ "$DIRECTION" = "en,es" ]; then
        TARGET_LANG="es"
      elif [ "$DIRECTION" = "ru,es" ]; then
        TARGET_LANG="es"
      elif [ "$DIRECTION" = "es,en" ]; then
        TARGET_LANG="en"
      fi

    else
      TARGET_LANG="ru"
      TEXT="$INPUT"
    fi
    if [ -z "$CHOICE" ]; then
      exit 0
    fi

    TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")
    CHOICE=$(echo -e "Copy\nClose" | rofi -mesg "$TRANSLATION" -dmenu -p "Done:")
    if [ "$CHOICE" = "Copy" ]; then
      echo -n "$TRANSLATION" | wl-copy
    elif [ "$CHOICE" = "Close"]; then
      exit 0
    elif [ -z "$CHOICE" ]; then
      exit 0
    fi
  done
fi
