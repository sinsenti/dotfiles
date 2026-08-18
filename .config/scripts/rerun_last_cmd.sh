#!/usr/bin/env zsh
setopt aliases local_options

# Read dir (line 1) and command (line 2)
{
  read -r DIR
  read -r CMD
} <~/.cache/last_cmd

# Run headlessly in the target directory
OUTPUT=$(cd "$DIR" 2>&1 && eval "$CMD" 2>&1)
STATUS=$?

# Notify desktop
notify-send " Reran (${STATUS})" "Cmd: $CMD\n\n${OUTPUT:-(No output)}"
