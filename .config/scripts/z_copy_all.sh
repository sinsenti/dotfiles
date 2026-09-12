#!/bin/bash

SCRIPT_PATH="$HOME/dotfiles/.config/scripts/copy_all.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
  echo -e "\e[1;31mError: Target script not found at $SCRIPT_PATH\e[0m"
  exit 1
fi

search_term="$1"

# If no argument is passed, prompt interactively
if [ -z "$search_term" ]; then
  echo -e "\e[1;36mDirectory Selection\e[0m"
  echo -e " Current location: \e[1;33m$PWD\e[0m"
  echo " Options:"
  echo "   • Press [Enter] to use current directory"
  echo "   • Type 'i' for interactive zoxide picker (requires fzf)"
  echo "   • Type a keyword to search zoxide"
  echo
  read -p "Select choice or term: " search_term
fi

# Resolve target directory based on input
if [ -z "$search_term" ]; then
  TARGET_DIR="$PWD"
elif [ "$search_term" = "i" ]; then
  TARGET_DIR=$(zoxide query -i 2>/dev/null)
  if [ -z "$TARGET_DIR" ]; then
    echo -e "\e[1;31mNo directory selected.\e[0m"
    exit 1
  fi
else
  TARGET_DIR=$(zoxide query "$search_term" 2>/dev/null)
  if [ -z "$TARGET_DIR" ]; then
    echo -e "\e[1;31mError: No zoxide match found for '$search_term'\e[0m"
    exit 1
  fi
fi

echo -e "\n\e[1;32mTarget Directory:\e[0m $TARGET_DIR\n"
sleep 1

cd "$TARGET_DIR" || exit 1
"$SCRIPT_PATH"
