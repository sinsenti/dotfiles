#!/bin/bash

TARGET_SSID="InnoWarsaw"
was_offline=false

notify-send "Wi-Fi" "Wifi script start working"
while true; do
  # 1. FIRST DEFENSE: Is the Wi-Fi radio completely turned off?
  # If 'nmcli radio wifi' outputs 'disabled', force it on immediately.
  if [ "$(nmcli radio wifi)" = "disabled" ]; then
    if [ "$was_offline" = false ]; then
      # notify-send "Wi-Fi" "❌ Wi-Fi is turned off! Enabling radio..."
      was_offline=true
    fi
    nmcli radio wifi on
    sleep 2 # Give the hardware an extra moment to turn on from a cold start
  fi

  # 2. Check internet connectivity
  if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    if [ "$was_offline" = true ]; then
      # notify-send "Wi-Fi" "🎉 Successfully reconnected to $TARGET_SSID!"
      was_offline=false
    fi
  else
    # 3. Internet failed. Are we still attached to our router?
    # 4. We are genuinely disconnected from the network. Try to connect.
    if [ "$was_offline" = false ]; then
      # notify-send "Wi-Fi" "❌ Disconnected! Reconnecting to $TARGET_SSID..."
      was_offline=true
    fi

    nmcli con up id "$TARGET_SSID" >/dev/null 2>&1
  fi

  sleep 10
done
