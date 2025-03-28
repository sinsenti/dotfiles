#!/bin/bash

CONFIG_FILE="/home/sinsenti/.config/hypr/UserConfigs/WindowRules.conf"

if grep -q "windowrulev2.*1250 650.*floating:2" "$CONFIG_FILE"; then
  sed -i "/^windowrulev2.*1250 650.*floating:2/s/1250 650/1900 1000/" "$CONFIG_FILE"
  echo "floating:full screen"
else
  sed -i "/^windowrulev2.*1900 1000.*floating:2/s/1900 1000/1250 650/" "$CONFIG_FILE"
  echo "floating:1250 650 "
fi
