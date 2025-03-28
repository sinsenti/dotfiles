#!/bin/bash

CONFIG_FILE=/home/sinsenti/.config/hypr/UserConfigs/WindowRules.conf

LINE="windowrulev2 = noblur, class:^(kitty)$"

if grep -q "^#.*windowrulev2.*noblur.*kitty" "$CONFIG_FILE"; then
  sed -i "/^#.*windowrulev2.*noblur.*kitty/s/^#//" "$CONFIG_FILE"
else
  sed -i "/^windowrulev2.*noblur.*kitty/s/^/#/" "$CONFIG_FILE"
fi
