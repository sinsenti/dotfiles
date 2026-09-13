#!/usr/bin/env bash

# Open the scratchpad without a swap file. This runs in a normal tmux window,
# so tmux shortcuts remain available while editing.
exec nvim -n /tmp/scratch.md
