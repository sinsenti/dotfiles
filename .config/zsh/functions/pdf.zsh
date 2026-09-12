pdf() {
  local script_path="/home/user/dotfiles/.config/scripts/pdf_clean_extract.py"

  _prompt_var() {
    local prompt_text="$1"
    local target_var="$2"
    if [ -n "$ZSH_VERSION" ]; then
      read -r "${target_var}?${prompt_text}"
    else
      read -r -p "${prompt_text}" "${target_var}"
    fi
  }

  _pause_menu() {
    echo ""
    printf "Press any key to return to menu..."
    if [ -n "$ZSH_VERSION" ]; then
      read -k 1 _
    else
      read -n 1 -r -s _
    fi
    echo ""
  }

  _suggest_open() {
    local file="$1"
    [ ! -f "$file" ] && return

    echo ""
    printf "Open created file (%s)? [Enter/y = Yes, Esc/n = No]: " "$file"

    local k
    if [ -n "$ZSH_VERSION" ]; then
      read -k 1 k
    else
      read -n 1 -r -s k
    fi
    echo ""

    case "$k" in
      ""|$'\n'|$'\r'|y|Y)
        if [ -n "$TMUX" ]; then
          if [[ "$file" == *.pdf ]]; then
            tmux split-window -h "zathura \"$file\""
          else
            tmux split-window -h "${EDITOR:-less} \"$file\""
          fi
        else
          if [[ "$file" == *.pdf ]]; then
            zathura "$file" >/dev/null 2>&1 &
          else
            ${EDITOR:-less} "$file"
          fi
        fi
        ;;
      n|N|$'\x1b'|$'\e')
        echo "Skipped opening file."
        ;;
      *)
        echo "Skipped opening file."
        ;;
    esac
  }

  while true; do
    if [ -n "$ZSH_VERSION" ]; then
      setopt localoptions ksharrays nullglob
    else
      shopt -s nullglob
    fi

    local pdf_files=(*.pdf)
    local docx_files=(*.docx)

    echo "========================================"
    echo "          FILE MANAGER TOOLKIT          "
    echo "========================================"
    echo "Current directory: $(pwd)"
    echo ""
    echo "PDF files found:"
    if [ ${#pdf_files[@]} -gt 0 ]; then
      local idx=1
      for f in "${pdf_files[@]}"; do
        echo "  $idx) $f"
        ((idx++))
      done
    else
      echo "  (No PDF files in current directory)"
    fi
    echo "----------------------------------------"
    echo "1) Cut page range (qpdf)"
    echo "2) OCR PDF - Russian + English (ocrmypdf)"
    echo "3) Clean PDF text extraction to TXT (Python)"
    echo "4) Repair garbled text in Wayland clipboard (wl-copy)"
    echo "5) Extract text from DOCX file to TXT"
    echo "q/Esc) Quit"
    printf "Select [1-5 / Enter for fzf / q]: "

    if [ -n "$ZSH_VERSION" ]; then
      read -k 1 choice
    else
      read -n 1 -r -s choice
    fi
    echo ""
    echo ""

    if [ -z "$choice" ] || [ "$choice" = $'\n' ] || [ "$choice" = $'\r' ]; then
      if command -v fzf >/dev/null 2>&1; then
        local menu_selection
        menu_selection=$(printf "1) Cut page range (qpdf)\n2) OCR PDF - Russian + English (ocrmypdf)\n3) Clean PDF text extraction to TXT (Python)\n4) Repair garbled text in Wayland clipboard (wl-copy)\n5) Extract text from DOCX file to TXT\nq) Quit" | fzf --height=40% --layout=reverse --prompt="Select Action > ")
        case "$menu_selection" in
          1*) choice="1" ;;
          2*) choice="2" ;;
          3*) choice="3" ;;
          4*) choice="4" ;;
          5*) choice="5" ;;
          q*) choice="q" ;;
          *) continue ;;
        esac
      fi
    fi

    _select_pdf() {
      if [ ${#pdf_files[@]} -eq 0 ]; then
        echo "No PDF files found in current directory." >&2
        return 1
      fi

      echo "--- Select Target PDF File ---" >&2
      local p_idx=1
      for f in "${pdf_files[@]}"; do
        echo "  $p_idx) $f" >&2
        ((p_idx++))
      done
      echo "------------------------------" >&2

      local sel=""
      if command -v fzf >/dev/null 2>&1; then
        _prompt_var "Select PDF # [1-${#pdf_files[@]}] or press Enter for fzf: " sel
      else
        _prompt_var "Select PDF # [1-${#pdf_files[@]}]: " sel
      fi

      if [ -z "$sel" ] && command -v fzf >/dev/null 2>&1; then
        printf '%s\n' "${pdf_files[@]}" | fzf --height=40% --layout=reverse --prompt="Select PDF > "
      elif [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#pdf_files[@]}" ]; then
        echo "${pdf_files[$((sel - 1))]}"
      elif [ -f "$sel" ]; then
        echo "$sel"
      else
        echo ""
      fi
    }

    _select_docx() {
      if [ ${#docx_files[@]} -eq 0 ]; then
        echo "No DOCX files found in current directory." >&2
        return 1
      fi

      echo "--- Select Target DOCX File ---" >&2
      local d_idx=1
      for f in "${docx_files[@]}"; do
        echo "  $d_idx) $f" >&2
        ((d_idx++))
      done
      echo "-------------------------------" >&2

      local sel=""
      if command -v fzf >/dev/null 2>&1; then
        _prompt_var "Select DOCX # [1-${#docx_files[@]}] or press Enter for fzf: " sel
      else
        _prompt_var "Select DOCX # [1-${#docx_files[@]}]: " sel
      fi

      if [ -z "$sel" ] && command -v fzf >/dev/null 2>&1; then
        printf '%s\n' "${docx_files[@]}" | fzf --height=40% --layout=reverse --prompt="Select DOCX > "
      elif [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "${#docx_files[@]}" ]; then
        echo "${docx_files[$((sel - 1))]}"
      elif [ -f "$sel" ]; then
        echo "$sel"
      else
        echo ""
      fi
    }

    case "$choice" in
      q|Q|$'\x1b'|$'\e')
        break
        ;;
      1)
        pdf_in=$(_select_pdf)
        if [ -z "$pdf_in" ]; then
          echo "No PDF selected."
          _pause_menu
          continue
        fi
        _prompt_var "Enter page range (e.g. 3-25): " page_range
        [ -z "$page_range" ] && continue
        
        default_out="cut_${pdf_in}"
        _prompt_var "Enter output PDF name [default: ${default_out}]: " pdf_out
        pdf_out=${pdf_out:-"$default_out"}

        qpdf "$pdf_in" --pages . "$page_range" -- "$pdf_out"
        _suggest_open "$pdf_out"
        _pause_menu
        ;;
      2)
        pdf_in=$(_select_pdf)
        if [ -z "$pdf_in" ]; then
          echo "No PDF selected."
          _pause_menu
          continue
        fi
        
        default_out="ocr_${pdf_in}"
        _prompt_var "Enter output PDF name [default: ${default_out}]: " pdf_out
        pdf_out=${pdf_out:-"$default_out"}

        ocrmypdf --force-ocr -l rus+eng "$pdf_in" "$pdf_out"
        _suggest_open "$pdf_out"
        _pause_menu
        ;;
      3)
        pdf_in=$(_select_pdf)
        if [ -z "$pdf_in" ]; then
          echo "No PDF selected."
          _pause_menu
          continue
        fi
        
        default_txt="${pdf_in%.pdf}.txt"
        _prompt_var "Enter output TXT name [default: ${default_txt}]: " txt_out
        txt_out=${txt_out:-"$default_txt"}

        if [ -f "$script_path" ]; then
          python3 "$script_path" "$pdf_in" "$txt_out"
          _suggest_open "$txt_out"
        else
          echo "Error: Python script not found at $script_path"
        fi
        _pause_menu
        ;;
      4)
        wl-paste | python3 -c "import sys; print(sys.stdin.read().encode('latin1', errors='ignore').decode('cp1251', errors='ignore'), end='')" | wl-copy
        echo "Clipboard text repaired successfully!"
        _pause_menu
        ;;
      5)
        docx_in=$(_select_docx)
        if [ -z "$docx_in" ]; then
          echo "No DOCX selected."
          _pause_menu
          continue
        fi

        default_txt="${docx_in%.docx}.txt"
        _prompt_var "Enter output TXT name [default: ${default_txt}]: " txt_out
        txt_out=${txt_out:-"$default_txt"}

        python3 -c "
import sys, zipfile, xml.etree.ElementTree as ET
try:
    with zipfile.ZipFile(sys.argv[1]) as z:
        xml_content = z.read('word/document.xml')
    tree = ET.fromstring(xml_content)
    paragraphs = []
    for p in tree.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}p'):
        texts = [node.text for node in p.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t') if node.text]
        if texts:
            paragraphs.append(''.join(texts))
    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        f.write('\n\n'.join(paragraphs))
    print('Extraction complete!')
except Exception as e:
    print(f'Error extracting DOCX: {e}')
" "$docx_in" "$txt_out"

        _suggest_open "$txt_out"
        _pause_menu
        ;;
      *)
        echo "Invalid choice."
        _pause_menu
        ;;
    esac
  done
}
