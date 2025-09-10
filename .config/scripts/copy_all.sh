#!/bin/bash
output_file="backup_code.txt"
# Clear output file
>"$output_file"
echo "Full project code:" >>"$output_file"

find . -path ./.git -prune -o -type f -not -name "$output_file" -print | while IFS= read -r file; do
  echo "=== $file ===" >>"$output_file"
  cat "$file" >>"$output_file"
  echo -e "\n\n" >>"$output_file"
done

if command -v wl-copy &>/dev/null; then
  cat "$output_file" | wl-copy
  rm "$output_file"
  echo "Backup copied to clipboard"
fi
