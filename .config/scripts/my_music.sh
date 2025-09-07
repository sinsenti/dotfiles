#!/bin/bash

music_file="/home/sinsenti/Music/tranquility-study.mp4"

is_playing() {
  pgrep -x mpv >/dev/null &&
    pgrep -fa "$music_file" | grep -q mpv
}

if is_playing; then
  echo "Music is playing, stopping..."
  pkill -x mpv
  notify-send -u low -i audio-headphones "Music stopped"
else
  echo "Music is not playing, starting..."
  mpv --no-video "$music_file" &
  notify-send -u normal -i audio-headphones "Now Playing" "$(basename "$music_file")"
fi
