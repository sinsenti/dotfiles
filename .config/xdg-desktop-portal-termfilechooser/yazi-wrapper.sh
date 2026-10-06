#!/usr/bin/env bash
# Portal wrapper: optionally use a lightweight Yazi config and an existing
# Kitty instance. The portal expects this process to stay alive until Yazi exits.
set -u

multiple=${1:-0}
directory=${2:-0}
save=${3:-0}
path=${4:-}
out=${5:-}
debug=${6:-0}

if [[ "$debug" == 1 ]]; then
  set -x
fi

if [[ -z "$out" ]]; then
  printf 'missing chooser output path\n' >&2
  exit 2
fi

mode=${YAZI_CHOOSER_MODE:-both}
case "$mode" in
  standard) use_profile=0; use_remote=0 ;;
  lite)     use_profile=1; use_remote=0 ;;
  reuse)    use_profile=0; use_remote=1 ;;
  both)     use_profile=1; use_remote=1 ;;
  *) printf 'unknown YAZI_CHOOSER_MODE: %s\n' "$mode" >&2; exit 2 ;;
esac

profile_dir=${YAZI_CHOOSER_CONFIG_HOME:-"$HOME/.config/yazi-chooser"}
window_width=${YAZI_CHOOSER_WIDTH:-1200}
window_height=${YAZI_CHOOSER_HEIGHT:-800}
[[ "$window_width" =~ ^[0-9]+$ ]] || window_width=1200
[[ "$window_height" =~ ^[0-9]+$ ]] || window_height=800
yazi_bin=$(command -v yazi || true)
kitty_bin=$(command -v kitty || true)
kitten_bin=$(command -v kitten || true)

if [[ -z "$yazi_bin" ]]; then
  printf 'yazi not found in PATH\n' >&2
  exit 127
fi

args=(--chooser-file="$out")
if [[ "$directory" == 1 ]]; then
  args+=(--cwd-file="$out.1")
fi
if [[ -n "$path" ]]; then
  args+=("$path")
fi

run_new_kitty() {
  if [[ -z "$kitty_bin" ]]; then
    printf 'kitty not found in PATH\n' >&2
    return 127
  fi
  if (( use_profile )); then
    YAZI_CONFIG_HOME="$profile_dir" "$kitty_bin" \
      -o remember_window_size=no \
      -o "initial_window_width=$window_width" \
      -o "initial_window_height=$window_height" \
      "$yazi_bin" "${args[@]}"
  else
    env -u YAZI_CONFIG_HOME "$kitty_bin" \
      -o remember_window_size=no \
      -o "initial_window_width=$window_width" \
      -o "initial_window_height=$window_height" \
      "$yazi_bin" "${args[@]}"
  fi
}

run_in_existing_kitty() {
  local socket runner done_file window_id polls
  local -a sockets

  [[ -n "$kitten_bin" && -n "${XDG_RUNTIME_DIR:-}" ]] || return 1
  shopt -s nullglob
  sockets=("$XDG_RUNTIME_DIR"/kitty-focus-app-search-*.sock)
  shopt -u nullglob
  ((${#sockets[@]})) || return 1

  local tmp_dir
  tmp_dir=$(mktemp -d) || return 1
  runner="$tmp_dir/run-yazi.sh"
  done_file="$tmp_dir/done"

  cat >"$runner" <<'RUNNER'
#!/usr/bin/env bash
use_profile=$1
profile_dir=$2
done_file=$3
yazi_bin=$4
kitten_bin=$5
kitty_socket=$6
window_width=$7
window_height=$8
shift 8

if [[ "$use_profile" == 1 ]]; then
  export YAZI_CONFIG_HOME="$profile_dir"
else
  unset YAZI_CONFIG_HOME
fi

finish() {
  local status=$?
  trap - EXIT
  local marker_tmp="$done_file.tmp.$$"
  printf '%s\n' "$status" >"$marker_tmp" && mv -f -- "$marker_tmp" "$done_file"
}
trap finish EXIT

"$kitten_bin" @ --to "$kitty_socket" resize-os-window --self \
  --unit pixels --width "$window_width" --height "$window_height" \
  >/dev/null 2>&1 || true
"$yazi_bin" "$@"
RUNNER
  chmod 700 "$runner"

  for socket in "${sockets[@]}"; do
    [[ -S "$socket" ]] || continue
    "$kitten_bin" @ --to "unix:$socket" ls >/dev/null 2>&1 || continue

    window_id=$("$kitten_bin" @ --to "unix:$socket" launch \
      --type=os-window \
      --os-window-class=yazi-file-chooser \
      --os-window-title='Yazi file chooser' \
      --os-window-state=normal \
      --env "PATH=$PATH" \
      --env "YAZI_CONFIG_HOME=" \
      "$runner" "$use_profile" "$profile_dir" "$done_file" "$yazi_bin" \
      "$kitten_bin" "unix:$socket" "$window_width" "$window_height" \
      "${args[@]}" 2>/dev/null) || continue

    [[ -n "$window_id" ]] || continue

    polls=0
    while [[ ! -f "$done_file" ]]; do
      sleep 0.05
      ((polls += 1))
      if (( polls % 20 == 0 )); then
        local listing="$tmp_dir/kitty.json"
        if ! "$kitten_bin" @ --to "unix:$socket" ls >"$listing" 2>/dev/null; then
          break
        fi
        if ! python3 - "$window_id" "$listing" <<'CHECK_WINDOW'
import json
import sys

wanted, filename = sys.argv[1:]
try:
    with open(filename, encoding="utf-8") as stream:
        os_windows = json.load(stream)
    found = any(
        str(window.get("id")) == wanted
        for os_window in os_windows
        for tab in os_window.get("tabs", [])
        for window in tab.get("windows", [])
    )
except (OSError, ValueError, TypeError):
    sys.exit(2)
sys.exit(0 if found else 1)
CHECK_WINDOW
        then
          break
        fi
      fi
    done

    if [[ -f "$done_file" ]]; then
      "$kitten_bin" @ --to "unix:$socket" close-window --match "id:$window_id" --no-response >/dev/null 2>&1 || true
    fi
    rm -rf -- "$tmp_dir"
    return 0
  done

  rm -rf -- "$tmp_dir"
  return 1
}

if (( use_remote )) && run_in_existing_kitty; then
  status=0
else
  run_new_kitty
  status=$?
fi

if [[ "$directory" == 1 ]]; then
  if [[ ! -s "$out" && -s "$out.1" ]]; then
    cat "$out.1" >"$out"
  fi
  rm -f -- "$out.1"
fi

exit "$status"
