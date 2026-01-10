#!/usr/bin/env bash

# deps: rofi, wl-clipboard, trans (translate-shell), curl, jq, mpv

while true; do
  INPUT=$(rofi -dmenu -p "Format: LANG,LANG text | d word | dno word | just text for en->ru")
  [ $? -ne 0 ] && exit 0 # user Esc

  if [ -z "$INPUT" ]; then
    INPUT=$(wl-paste)
    [ -z "$INPUT" ] && exit 0
  fi

  DIRECTION=$(echo "$INPUT" | cut -d' ' -f1)
  TEXT=$(echo "$INPUT" | cut -d' ' -f2-)

  if [ "$DIRECTION" = "d" ] || [ "$DIRECTION" = "dno" ]; then
    if [ -z "$TEXT" ]; then
      TEXT=$(wl-paste)
      [ -z "$TEXT" ] && continue
    fi
    word=$(echo "$TEXT" | cut -d ' ' -f 1)

    url="https://api.dictionaryapi.dev/api/v2/entries/en/${word}"
    data=$(curl -s "$url")

    MESSAGE=$(echo "$data" | jq -r '
    .[0] as $e |
    "Word: \($e.word)\n" +
    "Phonetic: \(
        $e.phonetic //
        ([$e.phonetics[]? | select(.text != null) | .text][0]) //
        "N/A"
    )\n\n" +
    "Definition: \(
        $e.meanings[0].definitions[0].definition
    )"
    ')

    audio_url=$(echo "$data" | jq -r '
      .[0].phonetics[]? | select(.audio != null and .audio != "") | .audio
    ' | head -n1)

    if [ "$DIRECTION" = "d" ] && [ -n "$audio_url" ] && [ "$audio_url" != "null" ]; then
      mpv --no-video --really-quiet "$audio_url" >/dev/null 2>~/.local/state/mpv-dict.log &
    fi

    DCHOICE=$(echo -e "Copy\nClose" | rofi -mesg "$MESSAGE" -dmenu -p "Dict:")

    if [ "$DCHOICE" = "Copy" ]; then
      dict_url="https://dictionary.cambridge.org/dictionary/english/${word}"
      echo -n "$dict_url" | wl-copy
      # exit 0
    fi

    if [[ -z "$CHOICE" ]]; then
      exit 0

    fi
    continue
  fi
  # ---- END DICTIONARY MODE ----

  # ---- TRANSLATION MODES ----
  is_valid_direction=false
  case "$DIRECTION" in
  "en,ru" | "en" | "ru,en" | "ru" | "кг" | "en,es" | "ru,es" | "es,en" | "fj")
    is_valid_direction=true
    ;;
  esac

  if $is_valid_direction; then
    case "$DIRECTION" in
    "en,ru" | "en") TARGET_LANG="ru" ;;
    "ru,en" | "ru" | "кг") TARGET_LANG="en" ;;
    "en,es") TARGET_LANG="es" ;;
    "ru,es") TARGET_LANG="es" ;;
    "es,en") TARGET_LANG="en" ;;
    "fj") TARGET_LANG="ru" ;;
    esac
    if [ -z "$TEXT" ]; then
      TEXT=$(wl-paste)
      [ -z "$TEXT" ] && exit 0
    fi

    TRANSLATION=$(trans -b ":$TARGET_LANG" "$TEXT")

    CHOICE=$(echo -e "Copy\nClose" |
      rofi -mesg "$TRANSLATION" -dmenu -p "Done:")

  else
    TARGET_LANG="ru"
    TEXT="$INPUT"
    TMP_RU=$(trans -b "en:ru" "$TEXT")
    TRANSLATION=$(trans -b "ru:en" "$TMP_RU")
    MESSAGE="$TMP_RU"$'\n\n'"$TEXT"$'\n\n'"$TRANSLATION"

    CHOICE=$(echo -e "Copy\nClose" |
      rofi -mesg "$MESSAGE" -dmenu -p "Done:")
  fi

  if [ "$CHOICE" = "Copy" ]; then
    echo -n "$TRANSLATION" | wl-copy
    exit 0
  elif [ "$CHOICE" = "Close" ] || [ -z "$CHOICE" ]; then
    exit 0
  fi

done
