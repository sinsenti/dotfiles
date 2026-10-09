#!/usr/bin/env bash

# Search Clipboard Indicator's existing Wayland history with fzf.
# The extension's on-disk registry format is private; this adapter targets its
# JSON cache, so keep the extension updated and revisit this if that format changes.

export PATH="/usr/local/bin:/usr/bin:/bin:/snap/bin:$HOME/.local/bin:$PATH"

SCRIPT_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
SCRIPT_MODE="${1:-}"
CACHE_FILE="${CLIPBOARD_INDICATOR_CACHE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/clipboard-indicator@tudmotu.com/registry.txt}"
CACHE_DIR=$(dirname -- "$CACHE_FILE")
TMP_DIR=""

cleanup_temp() {
  [[ -z "$TMP_DIR" ]] || rm -rf -- "$TMP_DIR"
  TMP_DIR=""
}

helper() {
  python3 - "$CACHE_FILE" "$CACHE_DIR" "$@" <<'PY'
import json
import os
import subprocess
import sys
import unicodedata
from pathlib import Path

cache_file = Path(sys.argv[1])
cache_dir = Path(sys.argv[2])
mode = sys.argv[3]


MIMETYPE_ORDER = (
    "text/plain;charset=utf-8", "UTF8_STRING", "text/plain", "STRING",
    "image/gif", "image/png", "image/jpg", "image/jpeg", "image/webp",
    "image/svg+xml", "text/html",
)


def read_entries():
    try:
        with cache_file.open(encoding="utf-8") as source:
            entries = json.load(source)
    except FileNotFoundError:
        return []
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"Clipboard History: couldn't read Clipboard Indicator's cache: {exc}", file=sys.stderr)
        raise SystemExit(1)

    if isinstance(entries, dict):
        entries = entries.get("entries", entries.get("items"))
    if not isinstance(entries, list):
        print("Clipboard History: unsupported Clipboard Indicator cache format; expected a list of entries.", file=sys.stderr)
        raise SystemExit(1)
    if entries and not any(
        isinstance(entry, dict) and any(key in entry for key in ("contents", "content", "data"))
        for entry in entries
    ):
        print("Clipboard History: cache schema is unrecognized; Clipboard Indicator may have changed its format.", file=sys.stderr)
        raise SystemExit(1)
    return entries


def entry_mimetype(entry):
    mimetype = entry.get("mimetype", entry.get("mime_type", entry.get("mime")))
    if mimetype is None:
        return "text/plain;charset=utf-8"
    return mimetype if isinstance(mimetype, str) else None


def entry_contents(entry):
    for key in ("contents", "content", "data"):
        if key in entry:
            return entry[key]
    return None


def is_text(mimetype):
    return isinstance(mimetype, str) and (
        mimetype.startswith("text/") or mimetype in {"STRING", "UTF8_STRING"}
    )


def image_file(entry):
    raw_path = entry_contents(entry)
    if not isinstance(raw_path, str):
        return None
    try:
        root = cache_dir.resolve(strict=True)
        path = Path(raw_path).resolve(strict=True)
        # Clipboard Indicator stores cached image files directly in this folder.
        if path.parent != root or not path.is_file():
            return None
        return path
    except OSError:
        return None


def current_clipboard():
    fixture = os.environ.get("CLIPBOARD_HISTORY_CURRENT_FILE")
    if fixture:
        try:
            return (
                os.environ.get("CLIPBOARD_HISTORY_CURRENT_MIME", "text/plain;charset=utf-8"),
                Path(fixture).read_bytes(),
            )
        except OSError:
            return None

    try:
        offered = subprocess.run(
            ["wl-paste", "--list-types"], capture_output=True, check=True
        ).stdout.decode("utf-8", errors="replace").splitlines()
    except (OSError, subprocess.CalledProcessError):
        return None

    offered = set(offered)
    for mimetype in MIMETYPE_ORDER:
        if mimetype not in offered:
            continue
        try:
            result = subprocess.run(
                ["wl-paste", "--no-newline", "--type", mimetype],
                capture_output=True,
                check=True,
            )
        except (OSError, subprocess.CalledProcessError):
            continue
        return mimetype, result.stdout
    return None


def matches_current(mimetype, contents, image_path, current):
    if current is None:
        return False
    current_mimetype, current_data = current
    if not isinstance(current_mimetype, str):
        return False
    if is_text(mimetype):
        return is_text(current_mimetype) and isinstance(contents, str) and contents.encode("utf-8") == current_data
    if mimetype.startswith("image/") and current_mimetype.startswith("image/") and image_path is not None:
        try:
            return image_path.stat().st_size == len(current_data) and image_path.read_bytes() == current_data
        except OSError:
            return False
    return False


def printable(text, *, one_line=False):
    result = []
    for char in text:
        if char in "\r\n\t" and one_line:
            result.append(" ")
        elif char in "\n\t" and not one_line:
            result.append(char)
        elif unicodedata.category(char) in {"Cc", "Cf", "Cs"}:
            result.append(f"\\u{ord(char):04x}")
        else:
            result.append(char)
    value = "".join(result)
    return " ".join(value.split()) if one_line else value


def get_item(index):
    entries = read_entries()
    if index < 0 or index >= len(entries) or not isinstance(entries[index], dict):
        raise ValueError("That clipboard history item is no longer available.")

    entry = entries[index]
    mimetype = entry_mimetype(entry)
    contents = entry_contents(entry)
    if mimetype is None:
        raise ValueError("This history item has an invalid MIME type.")
    if is_text(mimetype) and isinstance(contents, str):
        return mimetype, contents.encode("utf-8")
    if mimetype.startswith("image/"):
        path = image_file(entry)
        if path is not None:
            return mimetype, path.read_bytes()
    raise ValueError("This history item is unsupported or its cached data is missing.")


def history_items(entries, current=None):
    recent_rank = 0
    for index in range(len(entries) - 1, -1, -1):
        entry = entries[index]
        if not isinstance(entry, dict):
            continue
        mimetype = entry_mimetype(entry)
        contents = entry_contents(entry)
        if mimetype is None:
            continue
        image_path = None
        if is_text(mimetype) and isinstance(contents, str):
            label, preview = printable(contents, one_line=True), contents
        elif mimetype.startswith("image/") and (image_path := image_file(entry)) is not None:
            label, preview = "IMAGE", "IMAGE"
        else:
            continue
        recent_rank += 1
        is_active = matches_current(mimetype, contents, image_path, current)
        yield index, recent_rank, is_active, label, preview, image_path


if mode == "list":
    current = current_clipboard()
    for index, recent_rank, is_active, label, _, _ in history_items(read_entries(), current):
        rank_label = f"{recent_rank}{'*' if is_active else ''}"
        print(f"{index}\t{rank_label}\t{label}")
elif mode == "prepare":
    try:
        output_dir = Path(sys.argv[4])
        preview_dir = output_dir / "previews"
        preview_dir.mkdir(parents=True, exist_ok=True)
        entries = read_entries()
        current = current_clipboard()
        with (output_dir / "items").open("w", encoding="utf-8") as items_file:
            for index, recent_rank, is_active, label, preview, image_path in history_items(entries, current):
                item_id = str(index)
                (preview_dir / f"{item_id}.txt").write_text(printable(preview), encoding="utf-8")
                if image_path is not None:
                    (preview_dir / f"{item_id}.image").write_text(str(image_path) + "\n", encoding="utf-8")
                rank_label = f"{recent_rank}{'*' if is_active else ''}"
                items_file.write(f"{index}\t{rank_label}\t{label}\n")
    except (IndexError, OSError) as exc:
        print(f"Clipboard History: couldn't prepare picker data: {exc}", file=sys.stderr)
        raise SystemExit(1)
elif mode == "copy":
    try:
        mimetype, data = get_item(int(sys.argv[4]))
        subprocess.run(["wl-copy", "--type", mimetype], input=data, check=True)
    except (IndexError, ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(f"Clipboard History: {exc}", file=sys.stderr)
        raise SystemExit(1)
else:
    raise SystemExit(f"Unknown helper mode: {mode}")
PY
}

run_picker() {
  local items_file preview_command selected item_id
  TMP_DIR=$(mktemp -d) || return 1
  items_file="$TMP_DIR/items"

  if ! helper prepare "$TMP_DIR"; then
    return 1
  fi
  if [[ ! -s "$items_file" ]]; then
    printf 'No text or image history found. Copy something first.\n' >&2
    return 0
  fi

  printf -v preview_command 'bash %q --preview %q {1}' "$SCRIPT_PATH" "$TMP_DIR/previews"
  if ! selected=$(fzf \
    --layout=reverse \
    --tiebreak=index \
    --height=85% \
    --border \
    --prompt='Clipboard > ' \
    --header='* = current clipboard · number = recency · Enter copies · Esc cancels' \
    --delimiter=$'\t' \
    --nth='2..' \
    --with-nth='2..' \
    --preview="$preview_command" \
    --preview-window='right,60%,wrap' \
    <"$items_file"); then
    return 0
  fi

  item_id="${selected%%$'\t'*}"
  [[ "$item_id" =~ ^[0-9]+$ ]] || return 0
  helper copy "$item_id"
}

preview_item() {
  local preview_dir="$1" item_id="$2" image_path dimensions
  local image_file="$preview_dir/$item_id.image"

  if [[ -r "$image_file" ]]; then
    IFS= read -r image_path <"$image_file" || return 0
    dimensions="${FZF_PREVIEW_COLUMNS:-}x${FZF_PREVIEW_LINES:-}"
    if [[ -n "${KITTY_WINDOW_ID:-}" ]] && command -v kitten >/dev/null 2>&1 && \
      [[ "$dimensions" =~ ^[0-9]+x[0-9]+$ ]]; then
      if (set -o pipefail; kitten icat --clear --transfer-mode=stream --unicode-placeholder \
        --stdin=no --place="$dimensions@0x0" "$image_path" | sed '$d' | sed $'$s/$/\e[m/'); then
        return 0
      fi
    fi
    if command -v chafa >/dev/null 2>&1 && [[ "$dimensions" =~ ^[0-9]+x[0-9]+$ ]]; then
      chafa -s "$dimensions" "$image_path"
    else
      printf 'IMAGE\n'
    fi
  else
    cat "$preview_dir/$item_id.txt"
  fi
}

close_popup_window() {
  [[ "${CLIPBOARD_HISTORY_CLOSE_WINDOW:-0}" == 1 && "$SCRIPT_MODE" == "--picker" ]] || return 0
  command -v kitten >/dev/null 2>&1 || return 0

  local socket_path remote
  remote="${CLIPBOARD_HISTORY_KITTY_SOCKET:-${KITTY_LISTEN_ON:-}}"
  if [[ -z "$remote" && -n "${XDG_RUNTIME_DIR:-}" ]]; then
    for socket_path in "$XDG_RUNTIME_DIR"/kitty-focus-app-search-*.sock; do
      [[ -S "$socket_path" ]] || continue
      remote="unix:$socket_path"
      break
    done
  fi

  if [[ -z "$remote" ]]; then
    printf 'Clipboard History: could not find Kitty remote-control socket to close popup.\n' >&2
    return 0
  fi

  if kitten @ --to "$remote" close-window --self --no-response >/dev/null 2>&1; then
    return 0
  fi
  if [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
    kitten @ --to "$remote" close-window \
      --match "id:$KITTY_WINDOW_ID" --no-response >/dev/null 2>&1 || true
  else
    printf 'Clipboard History: Kitty did not close the picker window.\n' >&2
  fi
}

exit_cleanup() {
  local status=$?
  cleanup_temp
  close_popup_window
  trap - EXIT
  exit "$status"
}
trap exit_cleanup EXIT

launch_popup() {
  local socket_path window_id

  if command -v kitten >/dev/null 2>&1 && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    for socket_path in "$XDG_RUNTIME_DIR"/kitty-focus-app-search-*.sock; do
      [[ -S "$socket_path" ]] || continue
      if window_id=$(kitten @ --to "unix:$socket_path" launch \
        --type=os-window \
        --title='Clipboard History' \
        --os-window-class=popup_switcher \
        --os-window-title='Clipboard History' \
        --os-window-state=normal \
        --env "PATH=$PATH" \
        --env "CLIPBOARD_HISTORY_CLOSE_WINDOW=1" \
        --env "CLIPBOARD_HISTORY_KITTY_SOCKET=unix:$socket_path" \
        bash "$SCRIPT_PATH" --picker 2>/dev/null); then
        kitten @ --to "unix:$socket_path" resize-os-window \
          --match "id:$window_id" --unit pixels --width 900 --height 600 >/dev/null 2>&1 || true
        return 0
      fi
    done
  fi

  if command -v kitty >/dev/null 2>&1; then
    kitty --name popup_switcher \
      --title 'Clipboard History' \
      -o close_on_child_exit=yes \
      -o remember_window_size=no \
      -o initial_window_width=900 \
      -o initial_window_height=600 \
      bash "$SCRIPT_PATH" --picker >/dev/null 2>&1 &
    return 0
  fi

  printf 'Clipboard History: Kitty is needed to open the picker outside a terminal.\n' >&2
  return 1
}

case "${1:-}" in
  --picker)
    command -v fzf >/dev/null 2>&1 || { printf 'Clipboard History: fzf is not installed.\n' >&2; exit 1; }
    command -v wl-copy >/dev/null 2>&1 || { printf 'Clipboard History: wl-copy is not installed.\n' >&2; exit 1; }
    run_picker
    picker_status=$?
    exit "$picker_status"
    ;;
  --preview)
    preview_item "${2:-}" "${3:-}"
    ;;
  --list)
    helper list
    ;;
  *)
    command -v python3 >/dev/null 2>&1 || { printf 'Clipboard History: python3 is not installed.\n' >&2; exit 1; }
    command -v fzf >/dev/null 2>&1 || { printf 'Clipboard History: fzf is not installed.\n' >&2; exit 1; }
    command -v wl-copy >/dev/null 2>&1 || { printf 'Clipboard History: wl-copy is not installed.\n' >&2; exit 1; }
    if [[ -t 0 && -t 1 ]]; then
      run_picker
    else
      launch_popup
    fi
    ;;
esac
