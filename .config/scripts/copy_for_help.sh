#!/bin/bash

output_file="backup_code.txt"

# Clear output file
>"$output_file"

echo "Full project code:" >>"$output_file"

# Find all files, excluding .git directory
find . -type f -not -path "./.git/*" -not -name "$output_file" | while read -r file; do
  # full_path=$(realpath "$file")
  echo "=== $file ===" >>"$output_file"
  cat "$file" >>"$output_file"
  echo -e "\n\n" >>"$output_file"
done

# echo "Find and correct all errors (if any)" >>"$output_file"
if command -v wl-copy &>/dev/null; then
  cat "$output_file" | wl-copy
  rm "$output_file"
  echo "Backup copied to clipboard"
fi
