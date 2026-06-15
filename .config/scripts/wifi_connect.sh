#!/bin/bash

# 1. Automatically grab the currently connected Wi-Fi SSID
# TARGET_SSID=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | cut -d':' -f2)
TARGET_SSID="InnoWarsaw"

if [ -z "$TARGET_SSID" ]; then
  echo "❌ Error: You are not currently connected to any Wi-Fi network."
  echo "Please connect to your target Wi-Fi manually once, then restart this script."
  exit 1
fi

echo "📡 Target Wi-Fi detected: [$TARGET_SSID]"
echo "Monitoring connection..."
echo "----------------------------------------"

while true; do
  # Check internet connectivity via ping
  if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    echo "$(date +'%H:%M:%S') - ✅ Online"
    # Optional: Print IP (throttled to not spam the terminal, or leave as is)
    curl -s https://icanhazip.com/
  else
    echo "$(date +'%H:%M:%S') - ❌ OFFLINE! Attempting reconnection to [$TARGET_SSID]..."

    # Ensure the radio is turned on
    nmcli radio wifi on
    sleep 0.5

    # Try to bring up the specific connection
    # nmcli will automatically wait for the SSID to appear and connect to it
    if nmcli con up id "$TARGET_SSID" >/dev/null 2>&1; then
      echo "$(date +'%H:%M:%S') - 🎉 Successfully reconnected to $TARGET_SSID!"
    else
      echo "$(date +'%H:%M:%S') - ⏳ Wi-Fi not found or failed to connect. Retrying..."
    fi
  fi

  sleep 2
done
