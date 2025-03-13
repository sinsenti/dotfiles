#!/bin/bash

# Configuration
BAR_HEIGHT=7   # Adjust as needed
BAR_SYMBOL="█" # The character used for the bars.  Try "▂", " ", "▏", "█" etc.
SPACE=" "      # Space between bars
SLEEP_DURATION=0.005

# Cava Configuration
CAVA_BARS=10       # Adjust for number of bars
CAVA_SENSITIVITY=4 # Adjust sensitivity

CAVA_COMMAND="cava -p <(cat <<EOF
[general]
bars = $CAVA_BARS
framerate = 60
[input]
method = pulse
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = $BAR_HEIGHT
EOF
)"

# Function to generate a bar of a given length
generate_bar() {
  local length=$1
  printf "%${length}s" | tr ' ' "$BAR_SYMBOL"
}

# Main loop
while true; do
  output=$(eval "$CAVA_COMMAND")

  # Format output for Waybar
  formatted_output=""
  for value in $output; do
    bar_length=$(echo "$value" | awk '{print int($1)}')
    bar=$(generate_bar $bar_length)
    formatted_output+="$bar$SPACE"
  done

  # Output JSON for Waybar
  echo "{\"text\": \"$formatted_output\"}"

  sleep $SLEEP_DURATION
done
