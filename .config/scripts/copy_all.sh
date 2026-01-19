#!/bin/bash
output_file="backup_code.txt"
exclude_dirs=(".git" "node_modules" "dist" "__pycache__")
exclude_files=("package-lock.json" "poetry.ock")

echo
echo "=========================================="
echo " Interactive exclusion setup"
echo "=========================================="
echo
echo "  [dir] Add directory to exclude"
echo "  [file] Add file to exclude"
echo "  [Enter] Continue with default script"
echo

while true; do
  read -p $'Choose option\n1) dir\n2) file\n3) Enter\n' choice
  if [[ "$choice" == "1" || "$choice" == "dir" ]]; then
    read -p "Enter directory name to exclude: " dir
    [[ -n "$dir" ]] && exclude_dirs+=("$dir")
    echo
    echo "    ${exclude_dirs[*]}"
    echo
  elif [[ "$choice" == "2" || "$choice" == "file" ]]; then
    read -p "Enter file name to exclude: " fname
    [[ -n "$fname" ]] && exclude_files+=("$fname")
    echo "   ${exclude_files[*]}"
    echo
  elif [[ -z "$choice" ]]; then
    break
  fi
done

echo
echo "=========================================="
echo " Exclusion summary"
echo "=========================================="
echo
echo "  Excluded directories:"
for dir in "${exclude_dirs[@]}"; do
  echo "    - $dir"
done
echo
echo "  Excluded files:"
for fname in "${exclude_files[@]}"; do
  echo "    - $fname"
done
echo

>"$output_file"
echo "Full project code:" >>"$output_file"

# Build the directory prune expression
prune_expr=""
for dir in "${exclude_dirs[@]}"; do
  prune_expr="$prune_expr -name $dir -o"
done
prune_expr="${prune_expr::-3}" # Remove trailing -o

# Dynamic find call using eval
eval "find . \\( $prune_expr \\) -type d -prune -o -type f -not -name \"$output_file\" -print" | while IFS= read -r file; do
  for fname in "${exclude_files[@]}"; do
    if [[ "$(basename "$file")" == "$fname" ]]; then
      continue 2
    fi
  done
  echo "=== $file ===" >>"$output_file"
  cat "$file" >>"$output_file"
  echo -e "\n\n" >>"$output_file"
done

if command -v wl-copy &>/dev/null; then
  cat "$output_file" | wl-copy
  rm "$output_file"
  echo
  echo "=========================================="
  echo "  Backup copied to clipboard"
  echo "=========================================="
  echo
fi

echo
echo "=========================================="
echo "  Backup done"
echo "=========================================="
echo
