#!/bin/bash

active_window=$(hyprctl activewindow | grep "class: " | awk '{print $2}')

if [ "$active_window" = "kitty" ]; then
  hyprctl switchxkblayout "at-translated-set-2-keyboard" 0
fi
