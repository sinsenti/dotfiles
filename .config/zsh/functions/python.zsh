
py() {
    setopt local_options null_glob

    local runner=""
    local runner_type=""

    local levels=("." ".." "../.." "../../..")
    
    for dir in "${levels[@]}"; do
        local abs_dir
        abs_dir=$(cd "$dir" 2>/dev/null && pwd)
        [[ -z "$abs_dir" ]] && continue

        # 1A. If 'uv' project files exist -> Auto-select UV immediately
        if command -v uv &>/dev/null && [[ -f "$dir/pyproject.toml" || -f "$dir/uv.lock" ]]; then
            runner_type="uv ($abs_dir)"
            runner="uv run --project \"$abs_dir\" python"
            break
        fi

        # 1B. Check for standard venv directories (.venv, venv, env)
        local found_venv=""
        for venv_name in .venv venv env; do
            if [[ -f "$dir/$venv_name/bin/python" ]]; then
                found_venv="$dir/$venv_name/bin/python"
                break
            fi
        done

        if [[ -n "$found_venv" ]]; then
            if command -v uv &>/dev/null; then
                runner_type="uv ($abs_dir)"
                runner="uv run --python \"$found_venv\" python"
            else
                runner_type="venv ($abs_dir)"
                runner="$found_venv"
            fi
            break
        fi

        # 1C. Only if MULTIPLE custom-named venvs exist
        local candidates_display=()
        local candidates_runner=()

        for py_bin in "$dir"/*/bin/python "$dir"/.*[a-zA-Z0-9_]*/bin/python; do
            if [[ -f "$py_bin" ]]; then
                local venv_dir=$(dirname $(dirname "$py_bin"))
                local venv_base=$(basename "$venv_dir")
                local abs_custom="$abs_dir/$venv_base"
                candidates_display+=("$venv_base ($abs_custom)")
                candidates_runner+=("$py_bin")
            fi
        done

        if [[ ${#candidates_display[@]} -gt 0 ]]; then
            if [[ ${#candidates_display[@]} -eq 1 ]]; then
                runner_type="${candidates_display[1]}"
                runner="${candidates_runner[1]}"
            else
                local chosen
                chosen=$(printf '%s\n' "${candidates_display[@]}" | fzf --layout=reverse --header="[ Select custom venv at $abs_dir ]")
                [[ -z "$chosen" ]] && return 1
                for i in {1..${#candidates_display[@]}}; do
                    if [[ "${candidates_display[$i]}" == "$chosen" ]]; then
                        runner_type="${candidates_display[$i]}"
                        runner="${candidates_runner[$i]}"
                        break
                    fi
                done
            fi
            break
        fi
    done

    # Fallback to system Python if no venv or uv found in 3 levels backward
    if [[ -z "$runner" ]]; then
        if command -v python3 &>/dev/null; then
            runner="python3"
            runner_type="system python3"
        else
            runner="python"
            runner_type="system python"
        fi
    fi

    # Execution or Interactive Script Picker
    if [[ $# -gt 0 ]]; then
        echo -e "\033[1;34m[Using $runner_type]\033[0m"
        eval "$runner $@"
        return
    fi

    local selected_file
    if command -v fd &>/dev/null; then
        selected_file=$(fd --type f --extension py --hidden \
            --exclude .git --exclude .venv --exclude venv --exclude env \
            --exclude __pycache__ --exclude .pytest_cache --exclude .tox \
            --exclude build --exclude dist \
            | fzf --layout=reverse --header="[ Runner: $runner_type | Select .py file to run ]" \
                  --preview 'bat --color=always --style=numbers {} 2>/dev/null || cat {}')
    else
        selected_file=$(find . \( -path '*/.*' -o -path '*/__pycache__*' -o -path '*/venv*' -o -path '*/.venv*' -o -path '*/build*' -o -path '*/dist*' \) -prune -o -type f -name '*.py' -print | sed 's#^\./##' \
            | fzf --layout=reverse --header="[ Runner: $runner_type | Select .py file to run ]" \
                  --preview 'bat --color=always --style=numbers {} 2>/dev/null || cat {}')
    fi

    if [[ -n "$selected_file" ]]; then
        echo -e "\033[1;32m[Running via $runner_type]:\033[0m $selected_file"
        eval "$runner \"$selected_file\""
    fi
}

va() {
    local venv_paths=(".venv" "venv" "env" "../.venv" "../venv")
    for p in "${venv_paths[@]}"; do
        if [ -f "$p/bin/activate" ]; then
            source "$p/bin/activate"
            echo "Activated virtualenv at: $p"
            return 0
        fi
    done
    echo "No virtualenv found (.venv, venv, env)"
    return 1
}
