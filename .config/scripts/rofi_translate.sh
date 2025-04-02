#!/bin/bash

# Define the target languages
RUSSIAN="ru"
ENGLISH="en"
SPANISH="es"

# Prompt the user to select the translation direction via Rofi
DIRECTION=$(echo -e "en->ru\nru->en\nen->es\nru->es\nsp->en" | rofi -dmenu -p "Select Translation Direction:")

# Exit if no input is provided
if [ -z "$DIRECTION" ]; then
  exit 0
fi

# Determine source and target languages based on the selected direction
case $DIRECTION in
"en->ru")
  SOURCE_LANG=$ENGLISH
  TARGET_LANG=$RUSSIAN
  ;;
"ru->en")
  SOURCE_LANG=$RUSSIAN
  TARGET_LANG=$ENGLISH
  ;;
"en->es")
  SOURCE_LANG=$ENGLISH
  TARGET_LANG=$SPANISH
  ;;
"ru->es")
  SOURCE_LANG=$RUSSIAN
  TARGET_LANG=$SPANISH
  ;;
"es->en")
  SOURCE_LANG=$SPANISH
  TARGET_LANG=$ENGLISH
  ;;
*)
  SOURCE_LANG=$ENGLISH
  TARGET_LANG=$RUSSIAN
  ;;
esac

# Prompt the user to input text via Rofi
TEXT=$(echo "" | rofi -dmenu -p "Enter text to translate:")

# Exit if no input is provided
if [ -z "$TEXT" ]; then
  exit 0
fi

# Use translate-shell to perform the translation
TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")

# echo "$TRANSLATION"
echo -e "$TRANSLATION" | rofi -dmenu -p "Translation:" | wl-copy
