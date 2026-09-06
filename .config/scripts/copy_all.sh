#!/bin/bash

output_file="backup_code.txt"
exclude_dirs=(".git" ".github" "infra" ".claude" "node_modules" "dist" "__pycache__" ".pytest_cache" ".idea" ".venv")
exclude_files=("package-lock.json" "poetry.lock" ".gitignore" "uv.lock" ".env")
auto_exclude_large=true
auto_exclude_gitignore=true

green="\e[1;32m"
cyan="\e[1;36m"
yellow="\e[1;33m"
red="\e[1;31m"
reset="\e[0m"

render_dashboard() {
  echo -e "${cyan}==========================================${reset}"
  echo -e "${cyan}  Current Project Structure (Level 1)     ${reset}"
  echo -e "${cyan}==========================================${reset}"

  local gi_dirs=()
  local gi_files=()
  if [ "$auto_exclude_gitignore" = true ] && [ -f .gitignore ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      if [[ "$line" == */ ]]; then
        gi_dirs+=("${line%/}")
      else
        gi_dirs+=("$line")
        gi_files+=("$line")
      fi
    done <.gitignore
  fi

  local all_dirs=("${exclude_dirs[@]}" "${gi_dirs[@]}")
  local all_files=("${exclude_files[@]}" "${gi_files[@]}")

  local exa_ignores=()
  local tree_ignore=""
  for item in "${all_dirs[@]}" "${all_files[@]}"; do
    exa_ignores+=("-I" "$item")
    tree_ignore+="$item|"
  done
  tree_ignore="${tree_ignore%|}"

  if command -v exa &>/dev/null; then
    exa --tree --header --icons -a --level=1 --group-directories-first "${exa_ignores[@]}"
  elif command -v eza &>/dev/null; then
    eza --tree --header --icons -a --level=1 --group-directories-first "${exa_ignores[@]}"
  elif command -v tree &>/dev/null; then
    if [ -n "$tree_ignore" ]; then
      tree -L 1 -a --dirsfirst -I "$tree_ignore"
    else
      tree -L 1 -a --dirsfirst
    fi
  else
    ls -F | head -n 40
  fi

  echo
  echo -e "${red}==========================================${reset}"
  echo -e "${red}  Space & Line Hogs Analysis             ${reset}"
  echo -e "${red}==========================================${reset}"

  echo -e "${yellow}Folders larger than 0.5 MB:${reset}"
  local folder_found=false
  while read -r path; do
    if [ -n "$path" ]; then
      local base=$(basename "$path")
      local skip_dir=false
      for d in "${all_dirs[@]}"; do
        if [ "$base" = "$d" ]; then
          skip_dir=true
          break
        fi
      done
      [ "$skip_dir" = true ] && continue

      du -sh "$path" 2>/dev/null | while read -r size p; do
        echo -e "  • ${red}[$size]${reset} $p"
      done
      folder_found=true
    fi
  done < <(du -k -d 1 . 2>/dev/null | awk '$1 >= 500 && $2 != "." {print $2}')

  if [ "$folder_found" = false ]; then
    echo -e "  • ${green}None${reset}"
  fi

  echo
  local base_args=()
  if [ ${#all_dirs[@]} -gt 0 ]; then
    base_args+=(\()
    for i in "${!all_dirs[@]}"; do
      [ "$i" -gt 0 ] && base_args+=(-o)
      base_args+=(-name "${all_dirs[$i]}")
    done
    base_args+=(\) -prune -o)
  fi
  base_args+=(-type f -not -name "$output_file")
  for fname in "${all_files[@]}"; do
    base_args+=(-not -name "$fname")
  done

  echo -e "${yellow}Files larger than 0.5 MB:${reset}"
  local file_found=false
  local hog_args=("${base_args[@]}" -size +500k -exec du -h {} +)

  while read -r size path; do
    if [ -n "$size" ]; then
      echo -e "  • ${red}[$size]${reset} $path"
      file_found=true
    fi
  done < <(find . "${hog_args[@]}" 2>/dev/null | sort -hr)

  if [ "$file_found" = false ]; then
    echo -e "  • ${green}None${reset}"
  fi

  echo
  echo -e "${yellow}Files with > 1000 lines:${reset}"
  local lines_found=false
  local line_args=("${base_args[@]}")

  while read -r lines path; do
    if [ -n "$lines" ]; then
      echo -e "  • ${red}[$lines lines]${reset} $path"
      lines_found=true
    fi
  done < <(find . "${line_args[@]}" -exec wc -l {} + 2>/dev/null | awk '$1 > 1000 && $2 != "total" {print $1, $2}' | sort -nr)

  if [ "$lines_found" = false ]; then
    echo -e "  • ${green}None${reset}"
  fi
  echo
}

clear

while true; do
  render_dashboard

  if [ "$auto_exclude_large" = true ]; then
    status_label="${green}ON (Files > 0.5MB will be skipped)${reset}"
  else
    status_label="${red}OFF (Files > 0.5MB will be parsed)${reset}"
  fi

  if [ "$auto_exclude_gitignore" = true ]; then
    git_label="${green}ON (.gitignore patterns will be skipped)${reset}"
  else
    git_label="${red}OFF (.gitignore patterns will be parsed)${reset}"
  fi

  echo -e "${cyan}==========================================${reset}"
  echo -e "${cyan}  Interactive Exclusion Setup             ${reset}"
  echo -e "${cyan}==========================================${reset}"
  echo -e "  Current Exclusions:"
  echo -e "    ${yellow}Dirs:${reset}  ${exclude_dirs[*]}"
  echo -e "    ${yellow}Files:${reset} ${exclude_files[*]}"
  echo -e "    ${yellow}Skip files > 0.5MB:${reset} $status_label"
  echo -e "    ${yellow}Skip .gitignore items:${reset} $git_label"
  echo -e "------------------------------------------"
  echo -e "  [1] Add directory name to exclude"
  echo -e "  [2] Add file name to exclude"
  echo -e "  [3] Toggle auto-exclude all files > 0.5 MB"
  echo -e "  [4] Force Refresh Screen Layout"
  echo -e "  [5] Restore file or directory back to project"
  echo -e "  [6] Toggle auto-exclude items from .gitignore"
  echo -e "  [Enter] Proceed with compilation"
  echo

  read -p "Choose option (1/2/3/4/5/6/Enter): " choice

  if [[ "$choice" == "1" || "$choice" == "dir" ]]; then
    read -p "Enter directory name to exclude: " dir
    [[ -n "$dir" ]] && exclude_dirs+=("$dir")
    clear
  elif [[ "$choice" == "2" || "$choice" == "file" ]]; then
    read -p "Enter file name to exclude: " fname
    [[ -n "$fname" ]] && exclude_files+=("$fname")
    clear
  elif [[ "$choice" == "3" ]]; then
    if [ "$auto_exclude_large" = true ]; then
      auto_exclude_large=false
    else
      auto_exclude_large=true
    fi
    clear
  elif [[ "$choice" == "4" ]]; then
    clear
  elif [[ "$choice" == "5" ]]; then
    echo
    read -p "Enter directory or file name to BRING BACK: " restore_item
    if [ -n "$restore_item" ]; then
      local new_dirs=()
      for d in "${exclude_dirs[@]}"; do
        if [[ "$d" != "$restore_item" ]]; then
          new_dirs+=("$d")
        fi
      done
      exclude_dirs=("${new_dirs[@]}")

      local new_files=()
      for f in "${exclude_files[@]}"; do
        if [[ "$f" != "$restore_item" ]]; then
          new_files+=("$f")
        fi
      done
      exclude_files=("${new_files[@]}")
    fi
    clear
  elif [[ "$choice" == "6" ]]; then
    if [ "$auto_exclude_gitignore" = true ]; then
      auto_exclude_gitignore=false
    else
      auto_exclude_gitignore=true
    fi
    clear
  elif [[ -z "$choice" ]]; then
    break
  else
    clear
    echo -e "${red}Invalid choice, try again.${reset}\n"
  fi
done

echo -e "Full project code:\n\n" >"$output_file"

final_dirs=("${exclude_dirs[@]}")
final_files=("${exclude_files[@]}")
if [ "$auto_exclude_gitignore" = true ] && [ -f .gitignore ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" == */ ]]; then
      final_dirs+=("${line%/}")
    else
      final_dirs+=("$line")
      final_files+=("$line")
    fi
  done <.gitignore
fi

find_args=()

if [ ${#final_dirs[@]} -gt 0 ]; then
  find_args+=(\()
  for i in "${!final_dirs[@]}"; do
    [ "$i" -gt 0 ] && find_args+=(-o)
    find_args+=(-name "${final_dirs[$i]}")
  done
  find_args+=(\) -prune -o)
fi

find_args+=(-type f -not -name "$output_file")

for fname in "${final_files[@]}"; do
  find_args+=(-not -name "$fname")
done

if [ "$auto_exclude_large" = true ]; then
  find_args+=(-not -size +500k)
fi

find_args+=(-print)

echo -e "\nProcessing workspace index..."

find . "${find_args[@]}" | while IFS= read -r file; do
  clean_path="${file#./}"
  ext="${clean_path##*.}"

  case "$ext" in
  js) lang="javascript" ;;
  ts) lang="typescript" ;;
  py) lang="python" ;;
  sh | bash) lang="bash" ;;
  yml | yaml) lang="yaml" ;;
  json) lang="json" ;;
  html) lang="html" ;;
  css) lang="css" ;;
  sql) lang="sql" ;;
  md) lang="markdown" ;;
  *) lang="$ext" ;;
  esac

  echo "### \`$clean_path\`" >>"$output_file"
  echo "" >>"$output_file"
  echo "\`\`\`$lang" >>"$output_file"
  cat "$file" >>"$output_file"
  echo "" >>"$output_file"
  echo "\`\`\`" >>"$output_file"
  echo -e "\n" >>"$output_file"
done

if command -v wl-copy &>/dev/null; then
  wl-copy <"$output_file"
  rm "$output_file"
  echo -e "\n${green}==========================================${reset}"
  echo -e "${green}  ✔ Backup cleanly copied to clipboard!   ${reset}"
  echo -e "${green}==========================================${reset}\n"
else
  echo -e "\n${green}==========================================${reset}"
  echo -e "${green}  ✔ Backup written to $output_file        ${reset}"
  echo -e "${green}==========================================${reset}\n"
fi
