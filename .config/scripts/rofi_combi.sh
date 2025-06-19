#!/bin/bash

DIR1="$HOME/dotfiles/.config/scripts"
DIR2="$HOME/.config/hypr/UserScripts"
DIR3="$HOME/.config/hypr/scripts"

echo -e "calculator\ntranslator\nemoji\nshutdown\nsuspend\nsearch\nwallpaper\n" |
  rofi -i -dmenu -p "Select:" |
  while read -r choice; do
    case "$choice" in
    calculator)
      bash "$DIR2/RofiCalc.sh"
      ;;
    translator)
      bash $DIR1/rofi_translate.sh
      ;;
    emoji)
      bash $DIR3/RofiEmoji.sh
      ;;
    shutdown)
      shutdown now
      ;;
    suspend)
      systemctl suspend
      ;;
    search)
      bash $DIR3/RofiSearch.sh
      ;;
    wallpaper)
      bash $DIR2/WallpaperSelect.sh
      ;;
    *)
      # If no valid choice, just exit
      exit 0
      ;;
    esac
  done

exit
