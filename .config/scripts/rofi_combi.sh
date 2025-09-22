#!/bin/bash

DIR1="$HOME/dotfiles/.config/scripts"
DIR2="$HOME/.config/hypr/UserScripts"
DIR3="$HOME/.config/hypr/scripts"

echo -e "suspend\nmusic\ncalculator\ntranslator\nemoji\nshutdown\n\nsearch\nwallpaper\ndownloads\ngit" |
  rofi -i -dmenu -p "Select:" |
  while read -r choice; do
    case "$choice" in
    music)
      bash $DIR1/my_music.sh
      ;;
    translator)
      bash $DIR1/rofi_translate.sh
      ;;
    calculator)
      bash "$DIR2/RofiCalc.sh"
      ;;
    wallpaper)
      bash $DIR2/WallpaperSelect.sh
      ;;
    emoji)
      bash $DIR3/RofiEmoji.sh
      ;;
    search)
      bash $DIR3/RofiSearch.sh
      ;;
    shutdown)
      shutdown now
      ;;
    suspend)
      systemctl suspend
      ;;
    downloads)
      thunar Downloads
      ;;
    git)
      thunar git
      ;;
    *)
      # If no valid choice, just exit
      exit 0
      ;;
    esac
  done

exit
