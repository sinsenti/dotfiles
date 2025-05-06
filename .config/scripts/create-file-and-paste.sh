#!/bin/bash

read -p "Enter filename to create/write: " filepath

# Create directory if it doesn't exist
mkdir -p "$(dirname "$filepath")"

# Clear file if it exists or create new
: >"$filepath"

# Paste clipboard content into the file
wl-paste >"$filepath"
